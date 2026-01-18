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
    realtimeManager = RealtimeManager(mode: mode)
    syncQueue = SyncQueue(mode: mode)
    retryCoordinator = RetryCoordinator(mode: mode)
    circuitBreaker = CircuitBreaker()

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
    entitySyncHandler = EntitySyncHandler(
      mode: mode,
      conflictResolver: conflictResolver,
      getCurrentUserID: { [weak self] in self?.currentUserID },
      getCurrentUser: { [weak self] in self?.currentUser },
      fetchCurrentUser: { [weak self] id in self?.fetchCurrentUser(id: id) },
      updateListingConfigReady: { [weak self] ready in self?.isListingConfigReady = ready }
    )

    // Configure sync queue callback
    syncQueue.onSyncRequested = { [weak self] in
      await self?.sync()
    }

    // Configure circuit breaker state change callback
    circuitBreaker.onStateChange = { [weak self] state in
      self?.handleCircuitBreakerStateChange(state)
    }

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

  /// Preview-safe instance for SwiftUI previews.
  /// Uses .preview mode which disables all network and persistence side effects.
  static let preview = SyncManager(mode: .preview)

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
  @Published var syncStatus = SyncStatus.idle
  /// Current realtime connection state for error recovery UI.
  @Published var realtimeConnectionState = RealtimeConnectionState.connected
  @Published var currentUser: User? // The actual profile object, for UI state

  /// User-facing error message when syncStatus is .error
  @Published private(set) var lastSyncErrorMessage: String?

  /// Sync run counter for correlating claim actions with sync results
  @Published private(set) var syncRunId = 0

  /// Realtime manager for channel lifecycle and event handling
  private(set) var realtimeManager: RealtimeManager

  /// Sync queue for coalescing sync requests
  private(set) var syncQueue: SyncQueue

  /// Circuit breaker for sync retries
  private(set) var circuitBreaker: CircuitBreaker

  #if DEBUG
  /// For verifying shutdown logic without side effects
  var debugHangingTask: Task<Void, Never>?
  #endif

  /// Model container - internal for RealtimeManagerDelegate access
  private(set) var modelContainer: ModelContainer?

  /// Conflict resolver for in-flight tracking and conflict decisions
  let conflictResolver = ConflictResolver()

  /// Entity sync handler for all sync operations
  // swiftlint:disable:next implicitly_unwrapped_optional
  var entitySyncHandler: EntitySyncHandler!

  var isShutdown = false // Jobs Standard: Track lifecycle state

  /// Core Tasks - delegated to syncQueue for loop management
  var syncLoopTask: Task<Void, Never>? {
    syncQueue.syncLoopTask
  }

  #if DEBUG
  /// Allows testing the coalescing loop logic without actual network syncs
  var _simulateCoalescingInTest: Bool {
    get { syncQueue._simulateCoalescingInTest }
    set { syncQueue._simulateCoalescingInTest = newValue }
  }
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
  /// Guaranteed to run on MainActor. Delegates to SyncQueue for loop management.
  func requestSync() {
    // Telemetry tracking for preview mode
    if mode == .preview {
      _telemetry_syncRequests += 1
    }
    syncQueue.requestSync()
  }

  /// Resets lastSyncTime to nil, forcing the next sync to run full reconciliation.
  /// Use this to manually trigger orphan cleanup when you suspect local/remote mismatch.
  func resetLastSyncTime() {
    debugLog.log("resetLastSyncTime() called - next sync will run FULL RECONCILIATION", category: .sync)
    lastSyncTime = nil
    // Also reset per-table watermarks so all entities are re-fetched
    lastSyncNotes = nil
    debugLog.log("  -> Also reset notes watermark", category: .sync)
    // Reset handler-specific watermarks
    UserDefaults.standard.removeObject(forKey: Self.lastSyncListingTypesKey)
    UserDefaults.standard.removeObject(forKey: Self.lastSyncActivityTemplatesKey)
    debugLog.log("  -> Also reset listing types and activity templates watermarks", category: .sync)
  }

  /// Detects if the local database is empty but sync timestamps are set (stale state).
  /// This can happen after app reinstall or database reset when UserDefaults survive via iCloud backup.
  /// If detected, automatically resets sync timestamps to trigger full reconciliation.
  func detectAndResetStaleTimestamp() {
    guard let container = modelContainer else { return }
    guard lastSyncTime != nil else { return } // Already needs full sync

    let context = container.mainContext

    do {
      let listingCount = try context.fetchCount(FetchDescriptor<Listing>())
      let taskCount = try context.fetchCount(FetchDescriptor<TaskItem>())
      let activityCount = try context.fetchCount(FetchDescriptor<Activity>())

      // If all core entity types are empty but we have a lastSyncTime, something is wrong
      if listingCount == 0, taskCount == 0, activityCount == 0 {
        debugLog.log(
          "Warning: Database appears empty but lastSyncTime is set - resetting for full reconciliation",
          category: .sync
        )
        debugLog.log(
          "  Counts: listings=\(listingCount), tasks=\(taskCount), activities=\(activityCount)",
          category: .sync
        )
        resetLastSyncTime()
      }
    } catch {
      debugLog.error("Failed to check entity counts for stale timestamp detection", error: error)
    }
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

      // Get local note IDs for this parent.
      //
      // SwiftData Limitation: Predicates cannot use enum properties directly because
      // #Predicate cannot call .rawValue on enums at compile time. We fetch by parentId
      // only, then filter by parentType in memory.
      //
      // Performance Note: This in-memory filter is acceptable given expected data patterns
      // (few notes per parent). If a parentId ever has many notes, this could become a
      // bottleneck requiring a different approach (e.g., storing rawValue separately).
      let localDescriptor = FetchDescriptor<Note>(predicate: #Predicate {
        $0.parentId == parentId
      })
      let allNotesForParent = try context.fetch(localDescriptor)
      let localNotes = allNotesForParent.filter { $0.parentType == parentType }
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

  /// Retry syncing a specific TaskItem with exponential backoff.
  /// - Returns: true if retry was attempted, false if max retries exceeded.
  @discardableResult
  func retryTask(_ task: TaskItem) async -> Bool {
    await retryCoordinator.retryTask(task) { [weak self] in
      await self?.sync()
    }
  }

  /// Retry syncing a specific Activity with exponential backoff.
  /// - Returns: true if retry was attempted, false if max retries exceeded.
  @discardableResult
  func retryActivity(_ activity: Activity) async -> Bool {
    await retryCoordinator.retryActivity(activity) { [weak self] in
      await self?.sync()
    }
  }

  /// Retry syncing a specific Listing with exponential backoff.
  /// - Returns: true if retry was attempted, false if max retries exceeded.
  @discardableResult
  func retryListing(_ listing: Listing) async -> Bool {
    await retryCoordinator.retryListing(listing) { [weak self] in
      await self?.sync()
    }
  }

  /// Retry all failed entities with exponential backoff.
  /// Called on network restoration and app foreground.
  /// Respects max retries per entity - entities that exceed limit remain in .failed state.
  func retryFailedEntities() async {
    guard let container = modelContainer else {
      debugLog.log("retryFailedEntities(): No modelContainer", category: .sync)
      return
    }

    await retryCoordinator.retryFailedEntities(container: container) { [weak self] in
      await self?.sync()
    }
  }

  /// Auto-recover entities that have permanently failed (exceeded max retries).
  /// This resets entities so they can try syncing again, but only if enough time
  /// has passed since the last recovery attempt (cooldown period of 1 hour).
  ///
  /// Called on app foreground to give stuck entities a chance to sync after
  /// server-side fixes have been deployed.
  ///
  /// - Returns: Number of entities that were recovered
  @discardableResult
  func autoRecoverFailedEntities() async -> Int {
    guard let container = modelContainer else {
      debugLog.log("autoRecoverFailedEntities(): No modelContainer", category: .sync)
      return 0
    }

    return await retryCoordinator.autoRecoverFailedEntities(container: container) { [weak self] in
      await self?.sync()
    }
  }

  /// Resets all failed entities so they can be retried, regardless of retry count.
  /// Use this when a schema issue or server bug has been fixed and you want to retry
  /// entities that previously exceeded maxRetries.
  /// - Parameter triggerSync: If true (default), triggers a sync after resetting entities.
  func resetFailedEntities(triggerSync: Bool = true) async {
    guard let container = modelContainer else {
      debugLog.log("resetFailedEntities(): No modelContainer", category: .sync)
      return
    }

    let context = container.mainContext

    var resetCounts = (tasks: 0, activities: 0, listings: 0)

    do {
      // Fetch and reset failed TaskItems
      let taskDescriptor = FetchDescriptor<TaskItem>()
      let allTasks = try context.fetch(taskDescriptor)
      for task in allTasks where task.syncState == .failed {
        task.retryCount = 0
        task.markPending()
        resetCounts.tasks += 1
      }

      // Fetch and reset failed Activities
      let activityDescriptor = FetchDescriptor<Activity>()
      let allActivities = try context.fetch(activityDescriptor)
      for activity in allActivities where activity.syncState == .failed {
        activity.retryCount = 0
        activity.markPending()
        resetCounts.activities += 1
      }

      // Fetch and reset failed Listings
      let listingDescriptor = FetchDescriptor<Listing>()
      let allListings = try context.fetch(listingDescriptor)
      for listing in allListings where listing.syncState == .failed {
        listing.retryCount = 0
        listing.markPending()
        resetCounts.listings += 1
      }

      let totalReset = resetCounts.tasks + resetCounts.activities + resetCounts.listings

      if totalReset == 0 {
        debugLog.log("resetFailedEntities(): No failed entities to reset", category: .sync)
        return
      }

      debugLog.log(
        "resetFailedEntities(): Reset \(totalReset) entities (\(resetCounts.tasks) tasks, \(resetCounts.activities) activities, \(resetCounts.listings) listings)",
        category: .sync
      )

      // Trigger sync if requested
      if triggerSync {
        debugLog.log("resetFailedEntities(): Triggering sync to retry reset entities", category: .sync)
        await sync()
      }
    } catch {
      debugLog.error("resetFailedEntities(): Failed to fetch entities", error: error)
    }
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

    // Check circuit breaker before attempting sync
    guard circuitBreaker.shouldAllowSync() else {
      debugLog.log("SKIPPING sync - circuit breaker is open", category: .sync)
      if let remaining = circuitBreaker.remainingCooldown {
        syncStatus = .circuitBreakerOpen(remainingSeconds: Int(remaining))
      }
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

        // Auto-detect and reset stale timestamps when database is empty
        // This handles the case where app was reinstalled but UserDefaults survived via iCloud backup
        detectAndResetStaleTimestamp()

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
        // Reset all retry counts on successful sync
        resetAllRetryCounts()
        // Record success with circuit breaker (resets failure count)
        circuitBreaker.recordSuccess()
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
        // Record failure with circuit breaker (may trip circuit).
        // Note: If circuit trips, handleCircuitBreakerStateChange callback sets syncStatus.
        circuitBreaker.recordFailure()
        // Only update status if this is still the current sync run and circuit didn't trip
        if syncRunId == runId, !circuitBreaker.isBlocking {
          syncStatus = .error
          lastSyncErrorMessage = userFacingMessage(for: error)
        } else if syncRunId == runId {
          // Circuit tripped - callback already set status, just update error message
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

  func stopListening() async {
    await realtimeManager.stopListening()
  }

  /// Attempt to reconnect realtime when network is restored.
  /// Resets retry counts and attempts a fresh connection.
  func attemptRealtimeReconnection() {
    realtimeManager.attemptReconnection()
  }

  // MARK: - Test Accessors (Internal API for white-box testing)

  /// Reconciles Listing-User relationships (exposed for testing)
  /// Delegates to EntitySyncHandler for the actual implementation.
  func reconcileListingRelationships(context: ModelContext) throws {
    try entitySyncHandler.reconcileListingRelationships(context: context)
  }

  // MARK: - Retry Tracking
  // Note: Retry counts are now persisted on entities (TaskItem.retryCount, Activity.retryCount,
  // Listing.retryCount) instead of in-memory. The markSynced() method on each entity resets
  // retryCount to 0 when sync succeeds.

  /// Legacy method for compatibility - retry counts are now reset via markSynced() on each entity.
  /// This is a no-op since entities reset their own retryCount when successfully synced.
  func resetAllRetryCounts() {
    // Retry counts are now persisted on entities and reset via markSynced().
    // This method is kept for API compatibility but is effectively a no-op.
    debugLog.log("Retry counts managed via entity.retryCount (persisted)", category: .sync)
  }

  /// Clears observer tokens (called from lifecycle extension)
  func clearObserverTokens() {
    observerTokens.removeAll()
  }

  // MARK: Private

  /// Retry coordinator for exponential backoff retry logic
  private let retryCoordinator: RetryCoordinator

  private var syncRequestedDuringSync = false
  private var wasDisconnected = false // Track disconnection for reconnect sync

  /// Tracks all active observer tokens for deterministic cleanup.
  private var observerTokens = [NSObjectProtocol]()

  private var isAuthenticated: Bool {
    currentUserID != nil
  }

  /// Handle circuit breaker state changes to update SyncStatus for UI notification.
  private func handleCircuitBreakerStateChange(_ state: CircuitBreakerState) {
    switch state {
    case .open(_, let cooldownDuration):
      // Circuit just tripped - notify user
      syncStatus = .circuitBreakerOpen(remainingSeconds: Int(cooldownDuration))
      debugLog.log(
        "SyncManager: Circuit breaker tripped - sync paused for \(Int(cooldownDuration))s",
        category: .sync
      )

    case .halfOpen:
      // Transitioning to half-open - ready to probe
      debugLog.log("SyncManager: Circuit breaker half-open - will probe on next sync", category: .sync)

    case .closed:
      // Circuit recovered - resume normal operation
      debugLog.log("SyncManager: Circuit breaker closed - sync resumed", category: .sync)
      // Don't change syncStatus here - let the next sync set the appropriate status
    }
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
}
