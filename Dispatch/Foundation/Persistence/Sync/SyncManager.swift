//
//  SyncManager.swift
//  Dispatch
//
//  Created for Phase 1.3: SyncManager Service
//  Orchestrates bidirectional sync between SwiftData and Supabase
//

import Combine
import CryptoKit
import Foundation
import Network
import PostgREST
import Supabase
import SwiftData

// MARK: - SyncRunMode

enum SyncRunMode: Sendable {
  case live
  case preview
  case test // Deterministic mode: no network, timers, or side effects
}

// MARK: - ProfileUpdateError

/// Errors that can occur when updating user profile
enum ProfileUpdateError: LocalizedError {
  case notAuthenticated

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      "You must be signed in to update your profile."
    }
  }
}

// MARK: - SyncManager

@MainActor
final class SyncManager: ObservableObject {

  // MARK: Lifecycle

  init(mode: SyncRunMode = .live) {
    self.mode = mode
    self.realtimeManager = RealtimeManager(mode: mode)

    // Only load expensive state in live mode
    if mode == .live {
      // Restore persisted lastSyncTime
      lastSyncTime = UserDefaults.standard.object(forKey: Self.lastSyncTimeKey) as? Date
    } else {
      lastSyncTime = nil
    }

    // Set self as delegate after initialization
    realtimeManager.delegate = self

    // Initialize entity sync handler AFTER self is fully initialized
    // so closures can safely capture weak self
    self.entitySyncHandler = EntitySyncHandler(
      mode: mode,
      conflictResolver: conflictResolver,
      getCurrentUserID: { [weak self] in self?.currentUserID },
      getCurrentUser: { [weak self] in self?.currentUser },
      fetchCurrentUser: { [weak self] id in self?.fetchCurrentUser(id: id) },
      updateListingConfigReady: { [weak self] ready in self?.isListingConfigReady = ready }
    )

    debugLog.log("SyncManager singleton initialized (mode: \(mode))", category: .sync)
    if mode == .live {
      debugLog.log("  Restored lastSyncTime: \(lastSyncTime?.description ?? "nil")", category: .sync)
    }
  }

  deinit {
    // Strict Jobs Standard: NO calls to actor-isolated state (isShutdown) here.
    // Lifecycle enforcement belongs in tests.
    // Only safe, non-isolated reads allowed.
  }

  // MARK: Internal

  typealias RunMode = SyncRunMode

  static let shared = SyncManager()

  static let lastSyncTimeKey = "dispatch.lastSyncTime"
  static let lastSyncListingTypesKey = "dispatch.lastSyncListingTypes"
  static let lastSyncActivityTemplatesKey = "dispatch.lastSyncActivityTemplates"
  static let lastSyncNotesKey = "dispatch.lastSyncNotes"

  nonisolated let mode: RunMode
  /// Internal counter for verifying preview isolation
  var _telemetry_syncRequests = 0

  @Published private(set) var isSyncing = false
  @Published private(set) var isListingConfigReady = false // UI gate for AddListingSheet
  @Published private(set) var syncError: Error?
  @Published private(set) var syncStatus = SyncStatus.idle
  @Published var currentUser: User? // The actual profile object, for UI state

  /// User-facing error message when syncStatus is .error
  @Published private(set) var lastSyncErrorMessage: String?

  /// Sync run counter for correlating claim actions with sync results
  @Published private(set) var syncRunId = 0

  /// Realtime manager for channel lifecycle and event handling
  private(set) var realtimeManager: RealtimeManager

  /// Conflict resolver for in-flight tracking and conflict decisions
  private let conflictResolver = ConflictResolver()

  /// Entity sync handler for all sync operations
  private var entitySyncHandler: EntitySyncHandler!

  /// Core Tasks
  var syncLoopTask: Task<Void, Never>?

  #if DEBUG
  /// For verifying shutdown logic without side effects
  var debugHangingTask: Task<Void, Never>?
  #endif

  #if DEBUG
  /// Allows testing the coalescing loop logic without actual network syncs
  var _simulateCoalescingInTest = false
  #endif

  @Published private(set) var lastSyncTime: Date? {
    didSet {
      // Jobs Standard: Isolated Persistance
      // Only persist in .live mode. Tests must effectively run in memory.
      if mode == .live {
        if let time = lastSyncTime {
          UserDefaults.standard.set(time, forKey: Self.lastSyncTimeKey)
        } else {
          UserDefaults.standard.removeObject(forKey: Self.lastSyncTimeKey)
        }
      }
    }
  }

  /// Last Sync for Notes (Incremental)
  @Published private(set) var lastSyncNotes: Date? {
    didSet {
      if mode == .live {
        if let time = lastSyncNotes {
          UserDefaults.standard.set(time, forKey: Self.lastSyncNotesKey)
        } else {
          UserDefaults.standard.removeObject(forKey: Self.lastSyncNotesKey)
        }
      }
    }
  }

  @Published var currentUserID: UUID? { // Set when authenticated
    didSet {
      // Attempt to load user from local DB immediately when ID changes
      if let id = currentUserID {
        fetchCurrentUser(id: id)
      } else {
        currentUser = nil
      }
    }
  }

  #if DEBUG
  /// Test Hook: Allows setting lastSyncTime in tests without triggering persistence side effects
  /// or violating read-only visibility.
  func _debugSetLastSyncTime(_ date: Date?) {
    lastSyncTime = date
  }
  #endif
  func configure(with container: ModelContainer) {
    debugLog.log("configure() called", category: .sync)
    modelContainer = container
    debugLog.log("  modelContainer set: \(container)", category: .sync)
  }

  /// Updates the current authenticated user and triggers sync logic
  func updateCurrentUser(_ userId: UUID?) {
    debugLog.log("updateCurrentUser() called: \(userId?.uuidString ?? "nil")", category: .sync)
    currentUserID = userId
  }

  /// Updates the current user's user type in Supabase and locally
  /// - Parameter newType: The new user type to set
  /// - Throws: If the update fails
  func updateUserType(_ newType: UserType) async throws {
    guard let user = currentUser else {
      debugLog.log("updateUserType: No current user", category: .sync)
      throw ProfileUpdateError.notAuthenticated
    }

    debugLog.log("updateUserType: Updating to \(newType.rawValue)", category: .sync)

    // Update in Supabase directly (RLS allows user to update their own profile)
    try await supabase
      .from("users")
      .update(["user_type": newType.rawValue, "updated_at": ISO8601DateFormatter().string(from: Date())])
      .eq("id", value: user.id.uuidString)
      .execute()

    // Update local model
    user.userType = newType
    user.updatedAt = Date()

    debugLog.log("updateUserType: Successfully updated to \(newType.rawValue)", category: .sync)
  }

  /// Coalescing sync request - replaces "fire and forget" tasks with a single consumer.
  /// Guaranteed to run on MainActor.
  func requestSync() {
    // Strict Preview Guard
    if mode == .preview {
      _telemetry_syncRequests += 1
      return
    }

    // Test Mode Guard
    // In .test, syncs must be manually triggered via `await sync()`
    // UNLESS we are specifically verifying the coalescing logic.
    if mode == .test {
      #if DEBUG
      if !_simulateCoalescingInTest {
        return
      }
      #else
      return
      #endif
    }

    // 1. Set Flag
    syncRequested = true

    // 2. Ensure Loop Exists
    if syncLoopTask == nil {
      debugLog.log("Starting sync loop...", category: .sync)
      syncLoopTask = Task {
        // Guaranteed Nil-ing: Clear property on exit (finish or cancel)
        // RULE: cleanup at bottom of scope via MainActor.run. NO defer watcher.

        // Drain Loop
        while !Task.isCancelled {
          // Check logic on MainActor
          let shouldRun = await MainActor.run {
            if self.syncRequested {
              self.syncRequested = false
              return true
            }
            return false
          }

          if !shouldRun { break }

          // Do the work (holds self strongly during execution)
          await self.sync()
        }

        // Explicit Cleanup: Must happen on MainActor
        await MainActor.run {
          self.syncLoopTask = nil
          debugLog.log("Sync loop exited.", category: .sync)
        }
      }
    } else {
      debugLog.log("Sync request coalesced into existing loop.", category: .sync)
    }
  }

  /// Resets lastSyncTime to nil, forcing the next sync to run full reconciliation.
  /// Use this to manually trigger orphan cleanup when you suspect local/remote mismatch.
  func resetLastSyncTime() {
    debugLog.log("resetLastSyncTime() called - next sync will run FULL RECONCILIATION", category: .sync)
    lastSyncTime = nil
    // Also reset per-table watermarks so all entities are re-fetched
    lastSyncNotes = nil
    debugLog.log("  -> Also reset notes watermark", category: .sync)
  }

  /// Refreshes notes for a specific parent (listing, task, or activity).
  /// Call this when viewing a detail screen to ensure notes are up-to-date.
  /// This is lightweight - only fetches notes for the specific parent.
  @MainActor
  func refreshNotesForParent(parentId: UUID, parentType: ParentType) async {
    // Skip if a full sync is already in progress (it will fetch notes anyway)
    guard !isSyncing else { return }
    guard modelContainer != nil else { return }

    debugLog.log("refreshNotesForParent(\(parentType.rawValue), \(parentId))", category: .sync)

    do {
      // Fetch notes for this parent from server
      let dtos: [NoteDTO] = try await supabase
        .from("notes")
        .select()
        .eq("parent_id", value: parentId.uuidString)
        .eq("parent_type", value: parentType.rawValue)
        .execute()
        .value

      debugLog.log("  Fetched \(dtos.count) notes for parent", category: .sync)

      // Get context AFTER async work to avoid stale reference
      guard let context = modelContainer?.mainContext else { return }

      // Get local note IDs for this parent
      let localDescriptor = FetchDescriptor<Note>(predicate: #Predicate {
        $0.parentId == parentId && $0.parentType == parentType
      })
      let localNotes = try context.fetch(localDescriptor)
      let localIds = Set(localNotes.map { $0.id })

      // Apply each note (handles insert/update)
      var insertedCount = 0
      var updatedCount = 0
      for dto in dtos {
        let wasNew = !localIds.contains(dto.id)
        try entitySyncHandler.applyRemoteNote(dto: dto, source: .syncDown, context: context)
        if wasNew { insertedCount += 1 } else { updatedCount += 1 }
      }

      if insertedCount > 0 || updatedCount > 0 {
        debugLog.log("  Applied \(insertedCount) new, \(updatedCount) updated notes", category: .sync)
      }
    } catch {
      debugLog.error("refreshNotesForParent failed: \(error.localizedDescription)")
    }
  }

  /// Performs a full sync with orphan reconciliation, regardless of lastSyncTime.
  /// This is useful for debugging or when you know data has been deleted on the server.
  func fullSync() async {
    debugLog.log("fullSync() called - forcing full reconciliation", category: .sync)
    let savedLastSyncTime = lastSyncTime
    lastSyncTime = nil // Temporarily reset to force reconciliation
    await sync()
    // Note: sync() will set a new lastSyncTime on success, so we don't restore savedLastSyncTime
    _ = savedLastSyncTime // Silence unused variable warning
  }

  /// Retry syncing a single failed entity. This triggers a full sync but ensures
  /// the entity's state is reset to .pending first (done in markPending).
  /// The normal sync flow will then pick it up.
  func retrySync() async {
    await sync()
  }

  /// Retry syncing a specific TaskItem
  func retryTask(_ task: TaskItem) async {
    debugLog.log("retryTask() called for \(task.id)", category: .sync)
    task.syncState = .pending
    task.lastSyncError = nil
    await sync()
  }

  /// Retry syncing a specific Activity
  func retryActivity(_ activity: Activity) async {
    debugLog.log("retryActivity() called for \(activity.id)", category: .sync)
    activity.syncState = .pending
    activity.lastSyncError = nil
    await sync()
  }

  /// Retry syncing a specific Listing
  func retryListing(_ listing: Listing) async {
    debugLog.log("retryListing() called for \(listing.id)", category: .sync)
    listing.syncState = .pending
    listing.lastSyncError = nil
    await sync()
  }

  func sync() async {
    // Increment sync run ID for correlating claim actions with sync results
    syncRunId &+= 1
    let runId = syncRunId

    #if DEBUG
    if _simulateCoalescingInTest {
      debugLog.log("[TEST] Simulated sync() runId: \(runId)", category: .sync)
      // Simulate work
      try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
      return
    }
    #endif

    debugLog.log("========== sync() STARTED (runId: \(runId)) ==========", category: .sync)
    debugLog.log("  isAuthenticated: \(isAuthenticated)", category: .sync)
    debugLog.log("  isSyncing: \(isSyncing)", category: .sync)
    debugLog.log("  currentUserID: \(currentUserID?.uuidString ?? "nil")", category: .sync)
    debugLog.log("  lastSyncTime: \(lastSyncTime?.description ?? "nil")", category: .sync)

    // Redundant guide but safe
    if mode == .preview {
      return
    }

    guard isAuthenticated else {
      debugLog.log("SKIPPING sync - not authenticated", category: .sync)
      if syncRunId == runId {
        syncStatus = .idle
      }
      return
    }

    guard let container = modelContainer else {
      debugLog.log("SKIPPING sync - no modelContainer", category: .sync)
      return
    }

    // Coalescing loop pattern: queue sync requests instead of cancelling in-flight requests
    // If already syncing, set flag and return - the active sync will run another pass when done
    if isSyncing {
      syncRequestedDuringSync = true
      debugLog.log("QUEUED sync - will run after current sync completes", category: .sync)
      return
    }

    var runAgain: Bool

    repeat {
      isSyncing = true
      syncRequestedDuringSync = false
      syncStatus = .syncing
      syncError = nil
      debugLog.startTiming("Full Sync")

      do {
        // CRITICAL FIX: Use mainContext instead of creating a new ModelContext
        // This ensures we see entities created in other parts of the app (e.g., SyncTestHarness)
        // Previously: let context = ModelContext(container) - this created an isolated context
        // that couldn't see unsaved entities from the UI's @Environment(\.modelContext)
        let context = container.mainContext
        debugLog.log("Using container.mainContext (shared context)", category: .sync)

        debugLog.startTiming("syncDown")
        try await syncDown(context: context)
        debugLog.endTiming("syncDown")

        debugLog.startTiming("syncUp")
        try await syncUp(context: context)
        debugLog.endTiming("syncUp")

        debugLog.log("Saving ModelContext...", category: .sync)
        try context.save()
        debugLog.log("ModelContext saved successfully", category: .sync)

        let syncTimestamp = Date()
        lastSyncTime = syncTimestamp
        // Only update status if this is still the current sync run
        if syncRunId == runId {
          syncStatus = .ok(Date())
          lastSyncErrorMessage = nil
        }
        debugLog.endTiming("Full Sync")
        debugLog.log("========== sync() COMPLETED at \(syncTimestamp) ==========", category: .sync)
      } catch {
        debugLog.endTiming("Full Sync")
        debugLog.error("========== sync() FAILED ==========", error: error)
        syncError = error
        // Only update status if this is still the current sync run
        if syncRunId == runId {
          syncStatus = .error
          lastSyncErrorMessage = userFacingMessage(for: error)
        }
      }

      isSyncing = false
      runAgain = syncRequestedDuringSync
      syncRequestedDuringSync = false

      if runAgain {
        debugLog.log("Running queued sync...", category: .sync)
      }
    } while runAgain
  }

  func startListening() async {
    await realtimeManager.startListening()
  }

  /// Deterministic shutdown with strict ordering: Unsubscribe -> Cancel -> Await -> Cleanup.
  /// Prevents deadlocks and ensures test isolation.
  func shutdown() async {
    if isShutdown { return }
    isShutdown = true

    debugLog.log("shutdown() called - starting deterministic teardown", category: .sync)

    // 1. Stop realtime listening (unsubscribe channels)
    await realtimeManager.stopListening()

    // 2. Cancel Tasks (Signal listeners to stop)
    debugLog.log("  Cancelling active tasks...", category: .sync)
    realtimeManager.cancelAllTasks()
    syncLoopTask?.cancel()

    #if DEBUG
    debugHangingTask?.cancel()
    #endif

    // 3. Await Tasks (Quiescence)
    debugLog.log("  Awaiting task quiescence...", category: .sync)

    if mode == .test {
      // Provable Termination: Fail if tasks don't exit
      do {
        try await withTimeout(seconds: 2.0) {
          await self.realtimeManager.awaitAllTasks()
          _ = await self.syncLoopTask?.result

          #if DEBUG
          _ = await self.debugHangingTask?.result
          #endif
        }
      } catch {
        debugLog.error("SyncManager.shutdown() timed out! Tasks stuck.")
      }
    } else {
      // In live/preview, just await (logging ensures visibility)
      await realtimeManager.awaitAllTasks()
      _ = await syncLoopTask?.result

      #if DEBUG
      _ = await debugHangingTask?.result
      #endif
    }

    // 4. Cleanup References
    realtimeManager.clearTaskReferences()
    syncLoopTask = nil

    #if DEBUG
    debugHangingTask = nil
    #endif

    // Clear observer tokens
    observerTokens.removeAll()

    debugLog.log("shutdown() complete. SyncManager is quiescent.", category: .sync)
  }

  #if DEBUG
  /// Spawns a dummy task for testing deterministic shutdown.
  /// Cooperative: Sleeps in small chunks to allow cancellation.
  /// Updates `debugHangingTask` so shutdown() can find it.
  func performDebugTask(duration: TimeInterval) {
    debugLog.log("DEBUG: performDebugTask started", category: .sync)
    debugHangingTask = Task { [weak self] in
      let chunk = 0.1
      var elapsed = 0.0
      while elapsed < duration {
        if Task.isCancelled { return }
        try? await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
        elapsed += chunk
      }
      // Self-clearing
      await MainActor.run { [weak self] in
        self?.debugHangingTask = nil
      }
    }
  }
  #endif

  func stopListening() async {
    await realtimeManager.stopListening()
  }

  // MARK: - Test Accessors (Internal API for white-box testing)

  /// Reconciles Listing-User relationships (exposed for testing)
  /// Delegates to EntitySyncHandler for the actual implementation.
  func reconcileListingRelationships(context: ModelContext) throws {
    try entitySyncHandler.reconcileListingRelationships(context: context)
  }

  // MARK: Private

  private var isShutdown = false // Jobs Standard: Track lifecycle state

  /// Model container - internal for RealtimeManagerDelegate access
  private(set) var modelContainer: ModelContainer?
  private var syncRequestedDuringSync = false
  private var wasDisconnected = false // Track disconnection for reconnect sync

  private var syncRequested = false

  /// Tracks all active observer tokens for deterministic cleanup.
  private var observerTokens = [NSObjectProtocol]()

  private var isAuthenticated: Bool {
    currentUserID != nil
  }

  private func fetchCurrentUser(id: UUID) {
    guard let container = modelContainer else { return }
    let context = container.mainContext
    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })

    do {
      if let user = try context.fetch(descriptor).first {
        currentUser = user
        debugLog.log("fetchCurrentUser: User found locally: \(user.name)", category: .sync)
      } else {
        currentUser = nil
        debugLog.log("fetchCurrentUser: User NOT found locally (yet)", category: .sync)
      }
    } catch {
      debugLog.error("Failed to fetch current user", error: error)
    }
  }

  /// Convert sync errors to user-friendly messages
  private func userFacingMessage(for error: Error) -> String {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost:
        return "No internet connection."
      case .timedOut:
        return "Connection timed out."
      default:
        return "Network error."
      }
    }

    // Detect Postgres/RLS errors with table-aware messaging
    // Note: PostgrestError handling ideally involves checking the error code (e.g. 42501 or PGRST102)
    let errorString = String(describing: error).lowercased()
    if errorString.contains("42501") || errorString.contains("permission denied") {
      // Provide table-specific error messages for better debugging
      if errorString.contains("notes") {
        return "Permission denied syncing notes."
      }
      if errorString.contains("listings") {
        return "Permission denied syncing listings."
      }
      if errorString.contains("tasks") {
        return "Permission denied syncing tasks."
      }
      if errorString.contains("activities") {
        return "Permission denied syncing activities."
      }
      if errorString.contains("users") {
        return "Permission denied syncing user profile."
      }
      if errorString.contains("properties") {
        return "Permission denied syncing properties."
      }
      return "Permission denied during sync."
    }

    return "Sync failed: \(error.localizedDescription)"
  }

  private func syncDown(context: ModelContext) async throws {
    let lastSync = lastSyncTime ?? Date.distantPast
    let lastSyncISO = ISO8601DateFormatter().string(from: lastSync)
    debugLog.log("syncDown() - fetching records updated since: \(lastSyncISO)", category: .sync)

    // Determine if we should run full reconciliation
    // Run on first sync (no lastSyncTime) to ensure clean slate
    let shouldReconcile = lastSyncTime == nil
    if shouldReconcile {
      debugLog.log("Warning: First sync detected - will run FULL RECONCILIATION to remove orphan local records", category: .sync)
    }

    // Sync in order: ListingTypes -> ActivityTemplates -> Users -> Listings -> Tasks -> Activities (respects FK dependencies)
    // Types/Templates first since Listings reference them
    debugLog.log("Sync order: ListingTypes -> ActivityTemplates -> Users -> Listings -> Tasks -> Activities", category: .sync)

    debugLog.startTiming("syncDownListingTypes")
    try await entitySyncHandler.syncDownListingTypes(context: context)
    debugLog.endTiming("syncDownListingTypes")

    debugLog.startTiming("syncDownActivityTemplates")
    try await entitySyncHandler.syncDownActivityTemplates(context: context)
    debugLog.endTiming("syncDownActivityTemplates")

    debugLog.startTiming("syncDownUsers")
    try await entitySyncHandler.syncDownUsers(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownUsers")

    debugLog.startTiming("syncDownProperties")
    try await entitySyncHandler.syncDownProperties(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownProperties")

    debugLog.startTiming("syncDownListings")
    try await entitySyncHandler.syncDownListings(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownListings")

    debugLog.startTiming("syncDownTasks")
    try await entitySyncHandler.syncDownTasks(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownTasks")

    debugLog.startTiming("syncDownActivities")
    try await entitySyncHandler.syncDownActivities(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownActivities")

    debugLog.startTiming("syncDownTaskAssignees")
    try await entitySyncHandler.syncDownTaskAssignees(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownTaskAssignees")

    debugLog.startTiming("syncDownActivityAssignees")
    try await entitySyncHandler.syncDownActivityAssignees(context: context, since: lastSyncISO)
    debugLog.endTiming("syncDownActivityAssignees")

    // Notes (Incremental, Soft-Delete Aware)
    debugLog.startTiming("syncDownNotes")
    try await entitySyncHandler.syncDownNotes(context: context)
    debugLog.endTiming("syncDownNotes")

    // Notes Reconciliation - catches any notes missed by incremental sync
    debugLog.startTiming("reconcileMissingNotes")
    _ = try await entitySyncHandler.reconcileMissingNotes(context: context)
    debugLog.endTiming("reconcileMissingNotes")

    // JOBS-STANDARD: Order-Independent Relationship Reconciliation
    // Ensure Listing.owner is resolved regardless of sync order
    debugLog.startTiming("reconcileListingRelationships")
    try entitySyncHandler.reconcileListingRelationships(context: context)
    debugLog.endTiming("reconcileListingRelationships")

    // Reconcile Listing -> Property relationships
    debugLog.startTiming("reconcileListingPropertyRelationships")
    try entitySyncHandler.reconcileListingPropertyRelationships(context: context)
    debugLog.endTiming("reconcileListingPropertyRelationships")

    // ORPHAN RECONCILIATION: Remove local records that no longer exist on Supabase
    // This handles the case where records are hard-deleted on the server
    if shouldReconcile {
      debugLog.startTiming("reconcileOrphans")
      try await entitySyncHandler.reconcileOrphans(context: context)
      debugLog.endTiming("reconcileOrphans")
    }
  }

  private func syncUp(context: ModelContext) async throws {
    debugLog.log("syncUp() - pushing dirty entities to Supabase", category: .sync)

    // 0. Reconcile legacy "phantom" users (local-only but marked synced)
    // This is a lightweight local migration measure.
    try? await entitySyncHandler.reconcileLegacyLocalUsers(context: context)

    // Admin-only: ListingTypes and ActivityTemplates
    // Check if current user is admin
    let isAdmin = currentUser?.userType == .admin
    if isAdmin {
      debugLog.log("Admin user - syncing ListingTypes and ActivityTemplates", category: .sync)
      try await entitySyncHandler.syncUpListingTypes(context: context)
      try await entitySyncHandler.syncUpActivityTemplates(context: context)
    } else {
      debugLog.log("Non-admin user - skipping ListingTypes/Templates SyncUp", category: .sync)
    }

    debugLog.log(
      "Sync order: Users -> Properties -> Listings -> Tasks -> Activities -> Assignees -> Notes (FK dependencies)",
      category: .sync
    )

    // Sync in FK dependency order: Users first (owners), then Properties, then Listings, then Tasks/Activities
    try await entitySyncHandler.syncUpUsers(context: context)
    try await entitySyncHandler.syncUpProperties(context: context)
    try await entitySyncHandler.syncUpListings(context: context)
    try await entitySyncHandler.syncUpTasks(context: context)
    try await entitySyncHandler.syncUpActivities(context: context)
    try await entitySyncHandler.syncUpTaskAssignees(context: context)
    try await entitySyncHandler.syncUpActivityAssignees(context: context)
    try await entitySyncHandler.syncUpNotes(context: context)
    debugLog.log("syncUp() complete", category: .sync)
  }

  /// Helper for test timeout
  private func withTimeout(seconds: TimeInterval, operation: @escaping @Sendable () async -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      // Task 1: Operation
      group.addTask {
        await operation()
      }

      // Task 2: Timer
      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw CancellationError() // Timer won
      }

      // Wait for first completion
      do {
        try await group.next()
        // If operation finished first, cancel timer
        group.cancelAll()
      } catch {
        // If timer finished first (threw), cancel operation and rethrow
        group.cancelAll()
        if mode == .test {
          struct TimeoutError: Error { }
          throw TimeoutError()
        } else {
          debugLog.error("Operation timed out after \(seconds)s")
        }
      }
    }
  }

}

// MARK: - RealtimeManagerDelegate

extension SyncManager: RealtimeManagerDelegate {

  func realtimeManager(_ manager: RealtimeManager, didReceiveTaskDTO dto: TaskDTO) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      try entitySyncHandler.upsertTask(dto: dto, context: context)
    } catch {
      debugLog.error("Failed to upsert task from realtime", error: error)
    }
  }

  func realtimeManager(_ manager: RealtimeManager, didReceiveActivityDTO dto: ActivityDTO) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      try entitySyncHandler.upsertActivity(dto: dto, context: context)
    } catch {
      debugLog.error("Failed to upsert activity from realtime", error: error)
    }
  }

  func realtimeManager(_ manager: RealtimeManager, didReceiveListingDTO dto: ListingDTO) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      try entitySyncHandler.upsertListing(dto: dto, context: context)
    } catch {
      debugLog.error("Failed to upsert listing from realtime", error: error)
    }
  }

  func realtimeManager(_ manager: RealtimeManager, didReceiveUserDTO dto: UserDTO) {
    guard let context = modelContainer?.mainContext else { return }
    Task {
      do {
        try await entitySyncHandler.upsertUser(dto: dto, context: context)
      } catch {
        debugLog.error("Failed to upsert user from realtime", error: error)
      }
    }
  }

  func realtimeManager(_ manager: RealtimeManager, didReceiveNoteDTO dto: NoteDTO) {
    guard let context = modelContainer?.mainContext else { return }

    // Check pending protection before applying
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == dto.id })
    if let existing = try? context.fetch(descriptor).first {
      if existing.syncState == .pending || existing.syncState == .failed {
        debugLog.log("RT: Ignoring remote note for .pending Note \(dto.id)", category: .realtime)
        existing.hasRemoteChangeWhilePending = true
        return
      }
    }

    do {
      try entitySyncHandler.applyRemoteNote(dto: dto, source: .broadcast, context: context)
    } catch {
      debugLog.error("Failed to apply note from realtime", error: error)
    }
  }

  func realtimeManager(_ manager: RealtimeManager, didReceiveDeleteFor table: BroadcastTable, id: UUID) {
    guard let context = modelContainer?.mainContext else { return }
    do {
      switch table {
      case .tasks:
        _ = try entitySyncHandler.deleteLocalTask(id: id, context: context)
      case .activities:
        _ = try entitySyncHandler.deleteLocalActivity(id: id, context: context)
      case .listings:
        _ = try entitySyncHandler.deleteLocalListing(id: id, context: context)
      case .users:
        _ = try entitySyncHandler.deleteLocalUser(id: id, context: context)
      case .notes:
        // Hard delete from server = hard delete locally for notes
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
          context.delete(existing)
          debugLog.log("RT: Hard deleted note \(id)", category: .realtime)
        }
      }
    } catch {
      debugLog.error("Failed to delete \(table) from realtime", error: error)
    }
  }

  func realtimeManager(_ manager: RealtimeManager, statusDidChange status: SyncStatus) {
    syncStatus = status
  }

  func realtimeManager(_ manager: RealtimeManager, isInFlightTaskId id: UUID) -> Bool {
    conflictResolver.isTaskInFlight(id)
  }

  func realtimeManager(_ manager: RealtimeManager, isInFlightActivityId id: UUID) -> Bool {
    conflictResolver.isActivityInFlight(id)
  }

  func realtimeManager(_ manager: RealtimeManager, isInFlightNoteId id: UUID) -> Bool {
    conflictResolver.isNoteInFlight(id)
  }
}
