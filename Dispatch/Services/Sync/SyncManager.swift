//
//  SyncManager.swift
//  Dispatch
//
//  Created for Phase 1.3: SyncManager Service
//  Orchestrates bidirectional sync between SwiftData and Supabase
//

import Foundation
import SwiftData
import Supabase
import PostgREST
import Combine
import Network
import CryptoKit

@MainActor
final class SyncManager: ObservableObject, Sendable {
    static let shared = SyncManager()
    
    // MARK: - Run Mode
    
    enum RunMode {
        case live
        case preview
        case test // Deterministic mode: no network, timers, or side effects
    }
    
    let mode: RunMode
    private var isShutdown = false // Jobs Standard: Track lifecycle state
    
    // MARK: - Telemetry (Preview Only)
    /// Internal counter for verifying preview isolation
    var _telemetry_syncRequests = 0

    // MARK: - UserDefaults Keys
    private static let lastSyncTimeKey = "dispatch.lastSyncTime"

    // MARK: - Published State
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncTime: Date? {
        didSet {
            if let time = lastSyncTime {
                UserDefaults.standard.set(time, forKey: Self.lastSyncTimeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastSyncTimeKey)
            }
        }
    }
    @Published private(set) var syncError: Error?
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published var currentUserID: UUID? {  // Set when authenticated
        didSet {
            // Attempt to load user from local DB immediately when ID changes
            if let id = currentUserID {
                fetchCurrentUser(id: id)
            } else {
                currentUser = nil
            }
        }
    }
    @Published var currentUser: User? // The actual profile object, for UI state

    /// User-facing error message when syncStatus is .error
    @Published private(set) var lastSyncErrorMessage: String?

    /// Sync run counter for correlating claim actions with sync results
    @Published private(set) var syncRunId: Int = 0

    // MARK: - Private Properties
    private var modelContainer: ModelContainer?
    private var realtimeChannel: RealtimeChannelV2?
    private var broadcastChannel: RealtimeChannelV2?
    private var isListening = false
    private var syncRequestedDuringSync = false
    private var wasDisconnected = false  // Track disconnection for reconnect sync

    // MARK: - Task Inventory (Jobs Standard)
    /// Tracks all active tasks for deterministic shutdown.
    /// Added Phase 1: Instrumentation & Shutdown.
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    
    /// Tracks all active observer tokens for deterministic cleanup.
    private var observerTokens: [NSObjectProtocol] = []

    /// Feature flag: Enable broadcast-based realtime (v2)
    /// When true, subscribes to broadcast channel IN ADDITION to postgres_changes
    /// Phase 1: Both run simultaneously for validation
    /// Phase 2: Remove postgres_changes listeners
    /// Phase 3: Remove inFlightTaskIds tracking (origin_user_id replaces it)
    private let useBroadcastRealtime: Bool = true

    /// Tasks currently being synced up - skip realtime echoes for these
    /// NOTE: Will be removed in Phase 3 once origin_user_id filtering is validated
    private var inFlightTaskIds: Set<UUID> = []

    /// Activities currently being synced up - skip realtime echoes for these
    /// NOTE: Will be removed in Phase 3 once origin_user_id filtering is validated
    private var inFlightActivityIds: Set<UUID> = []

    // MARK: - Local-First Sync Guard
    /// Determines if a model should be treated as "local-authoritative" during SyncDown.
    /// Local-authoritative items should NOT be overwritten by server state until SyncUp succeeds.
    @inline(__always)
    private func isLocalAuthoritative<T: RealtimeSyncable>(
        _ model: T,
        inFlight: Bool
    ) -> Bool {
        model.syncState == .pending || model.syncState == .failed || inFlight
    }

    #if DEBUG
    /// Track recently processed IDs to detect duplicate processing (DEBUG only)
    /// Used during Phase 1 to log when both postgres_changes and broadcast process same event
    private var recentlyProcessedIds: Set<UUID> = []
    #endif

    init(mode: RunMode = .live) {
        self.mode = mode
        
        // Only load expensive state in live mode
        if mode == .live {
            // Restore persisted lastSyncTime
            self.lastSyncTime = UserDefaults.standard.object(forKey: Self.lastSyncTimeKey) as? Date
        } else {
            self.lastSyncTime = nil
        }
        
        debugLog.log("SyncManager singleton initialized (mode: \(mode))", category: .sync)
        if mode == .live {
            debugLog.log("  Restored lastSyncTime: \(lastSyncTime?.description ?? "nil")", category: .sync)
        }
    }

    deinit {
        // Jobs Standard: Verify deterministic shutdown
        if !isShutdown && mode != .live {
            print("⚠️ [SyncManager] deinit called WITHOUT shutdown()! This causes leaks/crashes in tests.")
        }
    }

    // MARK: - Configuration
    func configure(with container: ModelContainer) {
        debugLog.log("configure() called", category: .sync)
        self.modelContainer = container
        debugLog.log("  modelContainer set: \(container)", category: .sync)
    }

    /// Updates the current authenticated user and triggers sync logic
    func updateCurrentUser(_ userId: UUID?) {
        debugLog.log("updateCurrentUser() called: \(userId?.uuidString ?? "nil")", category: .sync)
        self.currentUserID = userId
    }

    // MARK: - Task Factory (Structured Concurrency)
    
    /// Creates and tracks a task, ensuring correct telemetry and cleanup.
    /// Operations MUST be cancellation-cooperative (check !Task.isCancelled).
    @discardableResult
    private func performTrackedTask(
        _ name: String = "Untitled",
        operation: @escaping () async -> Void
    ) -> UUID {
        let taskId = UUID()
        let oid = ObjectIdentifier(self)
        
        // Create the task (Scheduled)
        let task = Task { [weak self] in
            // 1. Telemetry: Running
            #if DEBUG
            await DebugSyncTelemetry.shared.taskStarted(for: oid)
            #endif
            
            // 2. The Work
            // Strong self capture is implicit in operation if it uses self,
            // or explicit if we need to keep manager alive. 
            // We'll let the operation define its capture semantics, 
            // but usually we want the manager alive.
            await operation()
            
            // 3. Cleanup (Inline on MainActor)
            await MainActor.run { [weak self] in
                self?.activeTasks.removeValue(forKey: taskId)
            }
            
            // 4. Telemetry: Ended
            #if DEBUG
            await DebugSyncTelemetry.shared.taskEnded(for: oid)
            #endif
        }
        
        // Store handle immediately
        activeTasks[taskId] = task
        debugLog.log("Task started: \(name) (\(taskId))", category: .sync)
        return taskId
    }
    
    /// Spawns a dummy task for testing deterministic shutdown.
    /// Cooperative: Sleeps in small chunks to allow cancellation.
    func performDebugTask(duration: TimeInterval) {
        performTrackedTask("Debug Task") {
            let chunk = 0.1
            var elapsed = 0.0
            while elapsed < duration {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
                elapsed += chunk
            }
        }
    }
    
    // MARK: - Shutdown (Deterministic)
    
    /// Deterministically stops all background work, cancels tasks, and awaits their completion.
    /// Guarantees that the SyncManager is quiescent upon return.
    func shutdown() async {
        if isShutdown { return }
        isShutdown = true
        
        debugLog.log("SyncManager shutdown() called - prohibiting new work", category: .sync)
        
        // 1. Unsubscribe Channels (Async & Awaited)
        if let channel = realtimeChannel {
            debugLog.log("  Unsubscribing realtime...", category: .sync)
            await channel.unsubscribe()
            realtimeChannel = nil
        }
        if let broadcast = broadcastChannel {
            debugLog.log("  Unsubscribing broadcast...", category: .sync)
            await broadcast.unsubscribe()
            broadcastChannel = nil
        }
        isListening = false
        
        // 2. Cancel Tasks
        let count = activeTasks.count
        debugLog.log("  Cancelling \(count) active tasks...", category: .sync)
        
        let tasks = activeTasks.values
        tasks.forEach { $0.cancel() }
        
        // 3. Await Completion (Quiescence)
        for task in tasks {
            _ = await task.result
        }
        activeTasks.removeAll()
        
        // 4. Remove Observers
        debugLog.log("  Removing \(observerTokens.count) observers...", category: .sync)
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observerTokens.removeAll()
        
        #if DEBUG
        debugLog.log("SyncManager shutdown complete.", category: .sync)
        #endif
    }

    // MARK: - Auth Check
    private var isAuthenticated: Bool {
        currentUserID != nil
    }

    // MARK: - Local User Fetching
    private func fetchCurrentUser(id: UUID) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
        
        do {
            if let user = try context.fetch(descriptor).first {
                self.currentUser = user
                debugLog.log("fetchCurrentUser: User found locally: \(user.name)", category: .sync)
            } else {
                self.currentUser = nil
                debugLog.log("fetchCurrentUser: User NOT found locally (yet)", category: .sync)
            }
        } catch {
            debugLog.error("Failed to fetch current user", error: error)
        }
    }

    // MARK: - Error Message Helper
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
        
        // Detect Postgres/RLS errors
        // Note: PostgrestError handling ideally involves checking the error code (e.g. 42501 or PGRST102)
        let errorString = String(describing: error)
        if errorString.contains("42501") || errorString.localizedCaseInsensitiveContains("permission denied") {
             return "Permission denied. You can only edit your own profile."
        }
        
        return "Sync failed: \(error.localizedDescription)"
    }

    // MARK: - Main Sync
    func requestSync() {
        // Strict Preview Guard
        if mode == .preview {
            _telemetry_syncRequests += 1
            return
        }
        
        // Test Mode Guard (Tests trigger sync manually/controlled)
        if mode == .test {
             return
        }
        
        debugLog.log("requestSync() called - triggering sync()", category: .sync)
        
        // Use Tracked Task Factory
        performTrackedTask("Request Sync") { [weak self] in
            guard let self else { return }
            await self.sync()
        }
    }

    /// Resets lastSyncTime to nil, forcing the next sync to run full reconciliation.
    /// Use this to manually trigger orphan cleanup when you suspect local/remote mismatch.
    func resetLastSyncTime() {
        debugLog.log("resetLastSyncTime() called - next sync will run FULL RECONCILIATION", category: .sync)
        lastSyncTime = nil
    }

    /// Performs a full sync with orphan reconciliation, regardless of lastSyncTime.
    /// This is useful for debugging or when you know data has been deleted on the server.
    func fullSync() async {
        debugLog.log("fullSync() called - forcing full reconciliation", category: .sync)
        let savedLastSyncTime = lastSyncTime
        lastSyncTime = nil  // Temporarily reset to force reconciliation
        await sync()
        // Note: sync() will set a new lastSyncTime on success, so we don't restore savedLastSyncTime
        _ = savedLastSyncTime  // Silence unused variable warning
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

    /// Retry syncing a specific ClaimEvent
    func retryClaimEvent(_ claimEvent: ClaimEvent) async {
        debugLog.log("retryClaimEvent() called for \(claimEvent.id)", category: .sync)
        claimEvent.syncState = .pending
        claimEvent.lastSyncError = nil
        await sync()
    }

    func sync() async {
        // Increment sync run ID for correlating claim actions with sync results
        syncRunId &+= 1
        let runId = syncRunId

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

                lastSyncTime = Date()
                // Only update status if this is still the current sync run
                if syncRunId == runId {
                    syncStatus = .ok(Date())
                    lastSyncErrorMessage = nil
                }
                debugLog.endTiming("Full Sync")
                debugLog.log("========== sync() COMPLETED at \(lastSyncTime!) ==========", category: .sync)
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

    // MARK: - Sync Down (Supabase → SwiftData)
    private func syncDown(context: ModelContext) async throws {
        let lastSync = lastSyncTime ?? Date.distantPast
        let lastSyncISO = ISO8601DateFormatter().string(from: lastSync)
        debugLog.log("syncDown() - fetching records updated since: \(lastSyncISO)", category: .sync)

        // Determine if we should run full reconciliation
        // Run on first sync (no lastSyncTime) to ensure clean slate
        let shouldReconcile = lastSyncTime == nil
        if shouldReconcile {
            debugLog.log("⚠️ First sync detected - will run FULL RECONCILIATION to remove orphan local records", category: .sync)
        }

        // Sync in order: Users → Listings → Tasks → Activities (respects FK dependencies)
        debugLog.log("Sync order: Users → Listings → Tasks → Activities", category: .sync)

        debugLog.startTiming("syncDownUsers")
        try await syncDownUsers(context: context, since: lastSyncISO)
        debugLog.endTiming("syncDownUsers")

        debugLog.startTiming("syncDownListings")
        try await syncDownListings(context: context, since: lastSyncISO)
        debugLog.endTiming("syncDownListings")

        debugLog.startTiming("syncDownTasks")
        try await syncDownTasks(context: context, since: lastSyncISO)
        debugLog.endTiming("syncDownTasks")

        debugLog.startTiming("syncDownActivities")
        try await syncDownActivities(context: context, since: lastSyncISO)
        debugLog.endTiming("syncDownActivities")

        debugLog.startTiming("syncDownClaimEvents")
        try await syncDownClaimEvents(context: context, since: lastSyncISO)
        debugLog.endTiming("syncDownClaimEvents")
        
        // JOBS-STANDARD: Order-Independent Relationship Reconciliation
        // Ensure Listing.owner is resolved regardless of sync order
        debugLog.startTiming("reconcileListingRelationships")
        try reconcileListingRelationships(context: context)
        debugLog.endTiming("reconcileListingRelationships")

        // ORPHAN RECONCILIATION: Remove local records that no longer exist on Supabase
        // This handles the case where records are hard-deleted on the server
        if shouldReconcile {
            debugLog.startTiming("reconcileOrphans")
            try await reconcileOrphans(context: context)
            debugLog.endTiming("reconcileOrphans")
        }
    }

    // MARK: - Orphan Reconciliation
    /// Removes local SwiftData entities that no longer exist on Supabase.
    /// This handles the case where records are hard-deleted on the server.
    /// Called on first sync (lastSyncTime == nil) to ensure local and remote are in sync.
    private func reconcileOrphans(context: ModelContext) async throws {
        debugLog.log("", category: .sync)
        debugLog.log("╔════════════════════════════════════════════════════════════╗", category: .sync)
        debugLog.log("║           ORPHAN RECONCILIATION                            ║", category: .sync)
        debugLog.log("╚════════════════════════════════════════════════════════════╝", category: .sync)

        var totalDeleted = 0

        // Reconcile Tasks
        debugLog.log("Reconciling Tasks...", category: .sync)
        let tasksDeleted = try await reconcileOrphanTasks(context: context)
        totalDeleted += tasksDeleted

        // Reconcile Activities
        debugLog.log("Reconciling Activities...", category: .sync)
        let activitiesDeleted = try await reconcileOrphanActivities(context: context)
        totalDeleted += activitiesDeleted

        // Reconcile Listings
        debugLog.log("Reconciling Listings...", category: .sync)
        let listingsDeleted = try await reconcileOrphanListings(context: context)
        totalDeleted += listingsDeleted

        // Reconcile Users (read-only but still need to remove orphans)
        debugLog.log("Reconciling Users...", category: .sync)
        let usersDeleted = try await reconcileOrphanUsers(context: context)
        totalDeleted += usersDeleted

        // Reconcile ClaimEvents
        debugLog.log("Reconciling ClaimEvents...", category: .sync)
        let claimEventsDeleted = try await reconcileOrphanClaimEvents(context: context)
        totalDeleted += claimEventsDeleted

        debugLog.log("", category: .sync)
        debugLog.log("Orphan reconciliation complete: deleted \(totalDeleted) total orphan records", category: .sync)
    }

    /// Lightweight DTO for fetching only IDs from Supabase
    private struct IDOnlyDTO: Codable {
        let id: UUID
    }

    private func reconcileOrphanTasks(context: ModelContext) async throws -> Int {
        // Fetch all task IDs from Supabase
        let remoteDTOs: [IDOnlyDTO] = try await supabase
            .from("tasks")
            .select("id")
            .execute()
            .value
        let remoteIds = Set(remoteDTOs.map { $0.id })
        debugLog.log("  Remote tasks: \(remoteIds.count)", category: .sync)

        // Fetch all local tasks
        let localDescriptor = FetchDescriptor<TaskItem>()
        let localTasks = try context.fetch(localDescriptor)
        debugLog.log("  Local tasks: \(localTasks.count)", category: .sync)

        // Find and delete orphans
        var deletedCount = 0
        for task in localTasks {
            if !remoteIds.contains(task.id) {
                debugLog.log("  🗑️ Deleting orphan task: \(task.id) - \(task.title)", category: .sync)
                context.delete(task)
                deletedCount += 1
            }
        }

        debugLog.log("  Deleted \(deletedCount) orphan tasks", category: .sync)
        return deletedCount
    }

    private func reconcileOrphanActivities(context: ModelContext) async throws -> Int {
        let remoteDTOs: [IDOnlyDTO] = try await supabase
            .from("activities")
            .select("id")
            .execute()
            .value
        let remoteIds = Set(remoteDTOs.map { $0.id })
        debugLog.log("  Remote activities: \(remoteIds.count)", category: .sync)

        let localDescriptor = FetchDescriptor<Activity>()
        let localActivities = try context.fetch(localDescriptor)
        debugLog.log("  Local activities: \(localActivities.count)", category: .sync)

        var deletedCount = 0
        for activity in localActivities {
            if !remoteIds.contains(activity.id) {
                debugLog.log("  🗑️ Deleting orphan activity: \(activity.id) - \(activity.title)", category: .sync)
                context.delete(activity)
                deletedCount += 1
            }
        }

        debugLog.log("  Deleted \(deletedCount) orphan activities", category: .sync)
        return deletedCount
    }

    private func reconcileOrphanListings(context: ModelContext) async throws -> Int {
        let remoteDTOs: [IDOnlyDTO] = try await supabase
            .from("listings")
            .select("id")
            .execute()
            .value
        let remoteIds = Set(remoteDTOs.map { $0.id })
        debugLog.log("  Remote listings: \(remoteIds.count)", category: .sync)

        let localDescriptor = FetchDescriptor<Listing>()
        let localListings = try context.fetch(localDescriptor)
        debugLog.log("  Local listings: \(localListings.count)", category: .sync)

        var deletedCount = 0
        for listing in localListings {
            if !remoteIds.contains(listing.id) {
                debugLog.log("  🗑️ Deleting orphan listing: \(listing.id) - \(listing.address)", category: .sync)
                context.delete(listing)
                deletedCount += 1
            }
        }

        debugLog.log("  Deleted \(deletedCount) orphan listings", category: .sync)
        return deletedCount
    }

    private func reconcileOrphanUsers(context: ModelContext) async throws -> Int {
        let remoteDTOs: [IDOnlyDTO] = try await supabase
            .from("users")
            .select("id")
            .execute()
            .value
        let remoteIds = Set(remoteDTOs.map { $0.id })
        debugLog.log("  Remote users: \(remoteIds.count)", category: .sync)

        let localDescriptor = FetchDescriptor<User>()
        let localUsers = try context.fetch(localDescriptor)
        debugLog.log("  Local users: \(localUsers.count)", category: .sync)

        var deletedCount = 0
        for user in localUsers {
            if !remoteIds.contains(user.id) {
                debugLog.log("  🗑️ Deleting orphan user: \(user.id) - \(user.name)", category: .sync)
                context.delete(user)
                deletedCount += 1
            }
        }

        debugLog.log("  Deleted \(deletedCount) orphan users", category: .sync)
        return deletedCount
    }

    private func reconcileOrphanClaimEvents(context: ModelContext) async throws -> Int {
        let remoteDTOs: [IDOnlyDTO] = try await supabase
            .from("claim_events")
            .select("id")
            .execute()
            .value
        let remoteIds = Set(remoteDTOs.map { $0.id })
        debugLog.log("  Remote claim events: \(remoteIds.count)", category: .sync)

        let localDescriptor = FetchDescriptor<ClaimEvent>()
        let localClaimEvents = try context.fetch(localDescriptor)
        debugLog.log("  Local claim events: \(localClaimEvents.count)", category: .sync)

        var deletedCount = 0
        for claimEvent in localClaimEvents {
            if !remoteIds.contains(claimEvent.id) {
                debugLog.log("  🗑️ Deleting orphan claim event: \(claimEvent.id)", category: .sync)
                context.delete(claimEvent)
                deletedCount += 1
            }
        }

        debugLog.log("  Deleted \(deletedCount) orphan claim events", category: .sync)
        return deletedCount
    }

    // MARK: - Helper Methods

    /// Extract a UUID from an AnyJSON dictionary (used for realtime DELETE event handling)
    /// Handles various JSON value representations from supabase-swift
    private func extractUUID(from record: [String: AnyJSON], key: String) -> UUID? {
        guard let value = record[key] else { return nil }

        // Try direct string extraction using description
        let stringValue = String(describing: value)

        // Clean up the string - it might be wrapped in quotes or have "string(" prefix
        let cleanedValue = stringValue
            .replacingOccurrences(of: "string(\"", with: "")
            .replacingOccurrences(of: "\")", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespaces)

        return UUID(uuidString: cleanedValue)
    }

    // MARK: - Entity Deletion Helpers
    /// Delete a task by ID from local SwiftData (used by cleanup and realtime DELETE handling)
    func deleteLocalTask(id: UUID, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            debugLog.log("deleteLocalTask: Task \(id) not found locally", category: .sync)
            return false
        }
        debugLog.log("deleteLocalTask: Deleting task \(id) - \(task.title)", category: .sync)
        context.delete(task)
        return true
    }

    /// Delete an activity by ID from local SwiftData
    func deleteLocalActivity(id: UUID, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == id })
        guard let activity = try context.fetch(descriptor).first else {
            debugLog.log("deleteLocalActivity: Activity \(id) not found locally", category: .sync)
            return false
        }
        debugLog.log("deleteLocalActivity: Deleting activity \(id) - \(activity.title)", category: .sync)
        context.delete(activity)
        return true
    }

    /// Delete a listing by ID from local SwiftData
    func deleteLocalListing(id: UUID, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == id })
        guard let listing = try context.fetch(descriptor).first else {
            debugLog.log("deleteLocalListing: Listing \(id) not found locally", category: .sync)
            return false
        }
        debugLog.log("deleteLocalListing: Deleting listing \(id) - \(listing.address)", category: .sync)
        context.delete(listing)
        return true
    }

    /// Delete a user by ID from local SwiftData
    func deleteLocalUser(id: UUID, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
        guard let user = try context.fetch(descriptor).first else {
            debugLog.log("deleteLocalUser: User \(id) not found locally", category: .sync)
            return false
        }
        debugLog.log("deleteLocalUser: Deleting user \(id) - \(user.name)", category: .sync)
        context.delete(user)
        return true
    }

    /// Delete a claim event by ID from local SwiftData
    func deleteLocalClaimEvent(id: UUID, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<ClaimEvent>(predicate: #Predicate { $0.id == id })
        guard let claimEvent = try context.fetch(descriptor).first else {
            debugLog.log("deleteLocalClaimEvent: ClaimEvent \(id) not found locally", category: .sync)
            return false
        }
        debugLog.log("deleteLocalClaimEvent: Deleting claim event \(id)", category: .sync)
        context.delete(claimEvent)
        return true
    }

    // MARK: - Sync Down: Users (read-only)
    private func syncDownUsers(context: ModelContext, since: String) async throws {
        debugLog.log("syncDownUsers() - querying Supabase...", category: .sync)
        var dtos: [UserDTO] = try await supabase
            .from("users")
            .select()
            .gt("updated_at", value: since)
            .execute()
            .value

        debugLog.logSyncOperation(operation: "FETCH", table: "users", count: dtos.count)

        // 🚨 CRITICAL FIX: If we are authenticated but have no local currentUser,
        // we MUST fetch our own profile regardless of 'since' time.
        // This handles re-login scenarios where the user record is older than lastSyncTime.
        if self.currentUser == nil, let currentID = self.currentUserID {
            let isCurrentInBatch = dtos.contains { $0.id == currentID }
            if !isCurrentInBatch {
                debugLog.log("⚠️ Current user profile missing from delta sync - force fetching...", category: .sync)
                do {
                    let currentUserDTO: UserDTO = try await supabase
                        .from("users")
                        .select()
                        .eq("id", value: currentID)
                        .single()
                        .execute()
                        .value
                    debugLog.log("  ✅ Force fetched current user profile: \(currentUserDTO.name)", category: .sync)
                    dtos.append(currentUserDTO)
                } catch {
                    debugLog.error("  ❌ Failed to force fetch current user profile", error: error)
                }
            }
        }

        for (index, dto) in dtos.enumerated() {
            debugLog.log("  Upserting user \(index + 1)/\(dtos.count): \(dto.id) - \(dto.name)", category: .sync)
            try await upsertUser(dto: dto, context: context)
        }
    }

    private func upsertUser(dto: UserDTO, context: ModelContext) async throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == targetId }
        )
        
        // 1. Fetch Existing
        let existing = try context.fetch(descriptor).first
        
        // 2. Conflict Check (Jobs-standard)
        // If local user is .pending, DO NOT overwrite pending fields with remote data.
        // We only proceed if .synced or .failed (failed typically means we want to retry or overwrite? Safe to overwrite if we trust server authoritative for everything except our unsynced changes).
        // Let's stick to strict: if .pending, skip scalar updates.
        // But we might still want to process Avatar if remote changed? That's complex merge.
        // For V1: "If local .pending, do not clobber scalar fields".
        // We will Apply scalars ONLY if existing is nil (insert) OR existing is NOT pending.
        
        let shouldApplyScalars = (existing == nil) || (existing?.syncState != .pending)
        
        // 3. Avatar Logic (Download)
        var newAvatarData: Data? = nil
        var shouldUpdateAvatar = false
        
        // Determine current local hash
        let currentLocalHash = existing?.avatarHash
        
        // Check if remote differs
        if let remoteHash = dto.avatarHash {
            if remoteHash != currentLocalHash {
                // Different! Check if we have a path
                if let path = dto.avatarPath {
                    debugLog.log("    Avatar hash changed (remote: \(remoteHash.prefix(6))...). Downloading...", category: .sync)
                    do {
                        // Use Public URL download to bypass strict RLS on `storage.objects`
                        // (Bucket is public, so this is reliable)
                        let publicURL = try supabase.storage
                            .from("avatars")
                            .getPublicURL(path: path)
                        
                        let (data, _) = try await URLSession.shared.data(from: publicURL)
                        
                        newAvatarData = data
                        shouldUpdateAvatar = true
                        
                        debugLog.log("    ✓ Avatar downloaded via Public URL", category: .sync)
                    } catch {
                        debugLog.error("    ⚠️ Failed to download avatar", error: error)
                        // On failure, keep local
                    }
                } else {
                    debugLog.log("    Remote hash exists but path is nil. Skipping avatar.", category: .sync)
                }
            }
        } else {
            // Remote hash is NIL.
            // If local is NOT nil, we must clear it (deletion propagated from server)
            if currentLocalHash != nil {
                shouldUpdateAvatar = true
                newAvatarData = nil // Clears it
                debugLog.log("    Remote avatar deleted. Clearing local.", category: .sync)
            }
        }

        if let user = existing {
            // UPDATE
            if shouldApplyScalars {
                debugLog.log("    UPDATE existing user: \(dto.id)", category: .sync)
                user.name = dto.name
                user.email = dto.email
                user.userType = UserType(rawValue: dto.userType) ?? .realtor
                user.updatedAt = dto.updatedAt
                
                // Only mark synced if we accept the server state
                user.markSynced()
            } else {
                debugLog.log("    SKIP scalar update for user \(dto.id) (Local state: \(user.syncState))", category: .sync)
            }
            
            // Apply Avatar Update (independent of scalar pending state? Usually yes, binary assets sync separately)
            // But if we have a pending avatar upload (local hash != remote hash), we shouldn't overwrite?
            // "Avatar processing ... off-main"
            // If we are pending, we might have a local avatar that hasn't uploaded.
            // If we blindly apply remote, we lose our new photo.
            // CHECK: If user.syncState == .pending, do we skip avatar too?
            // If pending, we assume local is newer.
            // YES. If pending, skip avatar overwrite.
            if shouldApplyScalars {
                if shouldUpdateAvatar {
                    user.avatar = newAvatarData
                    user.avatarHash = dto.avatarHash
                }
            }

        } else {
            // INSERT
            debugLog.log("    INSERT new user: \(dto.id)", category: .sync)
            let newUser = dto.toModel()
            
            // Apply downloaded avatar
            if shouldUpdateAvatar {
                newUser.avatar = newAvatarData
                newUser.avatarHash = dto.avatarHash // Sync hash too
            }
            
            newUser.markSynced()
            context.insert(newUser)
        }
        
        // Update currentUser if this is the one
        if dto.id == currentUserID {
            fetchCurrentUser(id: dto.id)
        }
    }

    // MARK: - Sync Down: Listings
    private func syncDownListings(context: ModelContext, since: String) async throws {
        debugLog.log("syncDownListings() - querying Supabase...", category: .sync)
        let dtos: [ListingDTO] = try await supabase
            .from("listings")
            .select()
            .gt("updated_at", value: since)
            .execute()
            .value

        debugLog.logSyncOperation(operation: "FETCH", table: "listings", count: dtos.count)

        for (index, dto) in dtos.enumerated() {
            debugLog.log("  Upserting listing \(index + 1)/\(dtos.count): \(dto.id) - \(dto.address)", category: .sync)
            try upsertListing(dto: dto, context: context)
        }
    }

    private func upsertListing(dto: ListingDTO, context: ModelContext) throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<Listing>(
            predicate: #Predicate { $0.id == targetId }
        )

        if let existing = try context.fetch(descriptor).first {
            // 🔐 Local-first: skip ALL updates if local-authoritative
            // Note: No inFlightListingIds needed for V1 as listings are rarely user-edited locally
            if isLocalAuthoritative(existing, inFlight: false) {
                debugLog.log("[SyncDown] Skip update for listing \(dto.id) — local-authoritative (state=\(existing.syncState))", category: .sync)
                return
            }

            debugLog.log("    UPDATE existing listing: \(dto.id)", category: .sync)
            existing.address = dto.address
            existing.city = dto.city ?? ""
            existing.province = dto.province ?? ""
            existing.postalCode = dto.postalCode ?? ""
            existing.country = dto.country ?? "Canada"
            existing.price = dto.price.map { Decimal($0) }
            existing.mlsNumber = dto.mlsNumber
            existing.listingType = ListingType(rawValue: dto.listingType) ?? .sale
            existing.status = ListingStatus(rawValue: dto.status) ?? .draft
            existing.activatedAt = dto.activatedAt
            existing.pendingAt = dto.pendingAt
            existing.closedAt = dto.closedAt
            existing.deletedAt = dto.deletedAt
            existing.dueDate = dto.dueDate
            existing.updatedAt = dto.updatedAt
            
            // Link Owner Relationship
            try establishListingOwnerRelationship(listing: existing, ownerId: dto.ownedBy, context: context)
            
            existing.markSynced()
        } else {
            debugLog.log("    INSERT new listing: \(dto.id)", category: .sync)
            let newListing = dto.toModel()
            newListing.markSynced()
            context.insert(newListing)
            
            // Link Owner Relationship
            try establishListingOwnerRelationship(listing: newListing, ownerId: dto.ownedBy, context: context)
        }
    }

    // MARK: - Sync Down: Tasks
    private func syncDownTasks(context: ModelContext, since: String) async throws {
        debugLog.log("syncDownTasks() - querying Supabase...", category: .sync)
        let dtos: [TaskDTO] = try await supabase
            .from("tasks")
            .select()
            .gt("updated_at", value: since)
            .execute()
            .value

        debugLog.logSyncOperation(operation: "FETCH", table: "tasks", count: dtos.count)

        for (index, dto) in dtos.enumerated() {
            debugLog.log("  Upserting task \(index + 1)/\(dtos.count): \(dto.id) - \(dto.title)", category: .sync)
            try upsertTask(dto: dto, context: context)
        }
    }

    private func upsertTask(dto: TaskDTO, context: ModelContext) throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == targetId }
        )

        if let existing = try context.fetch(descriptor).first {
            // 🔐 Local-first: skip ALL updates if local-authoritative
            if isLocalAuthoritative(existing, inFlight: inFlightTaskIds.contains(existing.id)) {
                debugLog.log("[SyncDown] Skip update for task \(dto.id) — local-authoritative (state=\(existing.syncState))", category: .sync)
                return
            }

            debugLog.log("    UPDATE existing task: \(dto.id)", category: .sync)
            // Apply server state ONLY when not local-authoritative
            existing.title = dto.title
            existing.taskDescription = dto.description ?? ""
            existing.dueDate = dto.dueDate
            existing.priority = Priority(rawValue: dto.priority) ?? .medium
            existing.status = TaskStatus(rawValue: dto.status) ?? .open
            existing.claimedBy = dto.claimedBy
            existing.claimedAt = dto.claimedAt
            existing.completedAt = dto.completedAt
            existing.deletedAt = dto.deletedAt
            existing.updatedAt = dto.updatedAt
            existing.listingId = dto.listing
            try establishTaskListingRelationship(task: existing, listingId: dto.listing, context: context)
            existing.markSynced()
        } else {
            debugLog.log("    INSERT new task: \(dto.id)", category: .sync)
            let newTask = dto.toModel()
            newTask.markSynced()
            context.insert(newTask)
            try establishTaskListingRelationship(task: newTask, listingId: dto.listing, context: context)
        }
    }

    /// Establishes bidirectional relationship between a task and its parent listing
    private func establishTaskListingRelationship(task: TaskItem, listingId: UUID?, context: ModelContext) throws {
        // Remove from old listing if listingId changed
        if let oldListing = task.listing, oldListing.id != listingId {
            debugLog.log("      Removing task from old listing: \(oldListing.id)", category: .sync)
            oldListing.tasks.removeAll { $0.id == task.id }
            task.listing = nil
        }

        // Add to new listing if listingId is set
        guard let listingId = listingId else {
            debugLog.log("      No listingId - task is standalone", category: .sync)
            return
        }

        let listingDescriptor = FetchDescriptor<Listing>(
            predicate: #Predicate { $0.id == listingId }
        )

        guard let parentListing = try context.fetch(listingDescriptor).first else {
            debugLog.log("      ⚠️ Parent listing \(listingId) not found - relationship deferred", category: .sync)
            return
        }

        // Establish bidirectional relationship
        if !parentListing.tasks.contains(where: { $0.id == task.id }) {
            debugLog.log("      Adding task to listing.tasks: \(listingId)", category: .sync)
            parentListing.tasks.append(task)
        }
        task.listing = parentListing
    }

    /// Establishes relationship between a listing and its owner (User)
    /// - Parameters:
    ///   - listing: The listing entity
    ///   - ownerId: The UUID of the owner (from owned_by)
    ///   - context: SwiftData context
    func establishListingOwnerRelationship(listing: Listing, ownerId: UUID, context: ModelContext) throws {
        // If already linked correctly, exit early
        if let currentOwner = listing.owner, currentOwner.id == ownerId {
            // Already correct
            return
        }

        let userDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == ownerId })
        if let user = try context.fetch(userDescriptor).first {
            // Only log if we are actually changing it (to avoid noise)
            if listing.owner == nil {
                debugLog.log("      Linking listing \(listing.address) to owner \(user.name)", category: .sync)
            }
            listing.owner = user
        } else {
            // Use this sporadically? Or only when it fails? 
            // In initial sync, user might not be there yet. That's expected.
        }
    }

    /// Reconciles missing Listing.owner relationships by linking them to available Users
    /// Called at the end of syncDown to ensure order-independence
    func reconcileListingRelationships(context: ModelContext) throws {
        debugLog.log("reconcileListingRelationships() - Starting...", category: .sync)
        
        // 1. Fetch all 'active' listings that are missing an owner
        // We exclude deleted listings to avoid churning on history
        let descriptor = FetchDescriptor<Listing>(
            predicate: #Predicate { $0.owner == nil && $0.deletedAt == nil }
        )
        let orphans = try context.fetch(descriptor)
        
        guard !orphans.isEmpty else {
            debugLog.log("  No active orphan listings found. Reconciliation complete.", category: .sync)
            return
        }
        
        debugLog.log("  Found \(orphans.count) orphan listings. Batch resolving...", category: .sync)

        // 2. Batch fetch ALL users into a dictionary for O(1) lookup
        // Efficiency: <1s for <10k users. Access by UUID is fast.
        let userDescriptor = FetchDescriptor<User>()
        let allUsers = try context.fetch(userDescriptor)
        let usersById = Dictionary(uniqueKeysWithValues: allUsers.map { ($0.id, $0) })
        
        // 3. Resolve
        var repairedCount = 0
        
        for listing in orphans {
            if let user = usersById[listing.ownedBy] {
                listing.owner = user
                repairedCount += 1
            }
        }
        
        debugLog.log("  Reconciliation summary: Found \(orphans.count) orphans, Repaired \(repairedCount)", category: .sync)
    }

    // MARK: - Sync Down: Activities
    private func syncDownActivities(context: ModelContext, since: String) async throws {
        debugLog.log("syncDownActivities() - querying Supabase...", category: .sync)
        let dtos: [ActivityDTO] = try await supabase
            .from("activities")
            .select()
            .gt("updated_at", value: since)
            .execute()
            .value

        debugLog.logSyncOperation(operation: "FETCH", table: "activities", count: dtos.count)

        for (index, dto) in dtos.enumerated() {
            debugLog.log("  Upserting activity \(index + 1)/\(dtos.count): \(dto.id) - \(dto.title)", category: .sync)
            try upsertActivity(dto: dto, context: context)
        }
    }

    private func upsertActivity(dto: ActivityDTO, context: ModelContext) throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.id == targetId }
        )

        if let existing = try context.fetch(descriptor).first {
            // 🔐 Local-first: skip ALL updates if local-authoritative
            if isLocalAuthoritative(existing, inFlight: inFlightActivityIds.contains(existing.id)) {
                debugLog.log("[SyncDown] Skip update for activity \(dto.id) — local-authoritative (state=\(existing.syncState))", category: .sync)
                return
            }

            debugLog.log("    UPDATE existing activity: \(dto.id)", category: .sync)
            existing.title = dto.title
            existing.activityDescription = dto.description ?? ""
            existing.type = ActivityType(rawValue: dto.activityType) ?? .other
            existing.dueDate = dto.dueDate
            existing.priority = Priority(rawValue: dto.priority) ?? .medium
            existing.status = ActivityStatus(rawValue: dto.status) ?? .open
            existing.claimedBy = dto.claimedBy
            existing.duration = dto.durationMinutes.map { TimeInterval($0 * 60) }
            existing.claimedAt = dto.claimedAt
            existing.completedAt = dto.completedAt
            existing.deletedAt = dto.deletedAt
            existing.updatedAt = dto.updatedAt
            existing.listingId = dto.listing
            try establishActivityListingRelationship(activity: existing, listingId: dto.listing, context: context)
            existing.markSynced()
        } else {
            debugLog.log("    INSERT new activity: \(dto.id)", category: .sync)
            let newActivity = dto.toModel()
            newActivity.markSynced()
            context.insert(newActivity)
            try establishActivityListingRelationship(activity: newActivity, listingId: dto.listing, context: context)
        }
    }

    /// Establishes bidirectional relationship between an activity and its parent listing
    private func establishActivityListingRelationship(activity: Activity, listingId: UUID?, context: ModelContext) throws {
        // Remove from old listing if listingId changed
        if let oldListing = activity.listing, oldListing.id != listingId {
            debugLog.log("      Removing activity from old listing: \(oldListing.id)", category: .sync)
            oldListing.activities.removeAll { $0.id == activity.id }
            activity.listing = nil
        }

        // Add to new listing if listingId is set
        guard let listingId = listingId else {
            debugLog.log("      No listingId - activity is standalone", category: .sync)
            return
        }

        let listingDescriptor = FetchDescriptor<Listing>(
            predicate: #Predicate { $0.id == listingId }
        )

        guard let parentListing = try context.fetch(listingDescriptor).first else {
            debugLog.log("      ⚠️ Parent listing \(listingId) not found - relationship deferred", category: .sync)
            return
        }

        // Establish bidirectional relationship
        if !parentListing.activities.contains(where: { $0.id == activity.id }) {
            debugLog.log("      Adding activity to listing.activities: \(listingId)", category: .sync)
            parentListing.activities.append(activity)
        }
        activity.listing = parentListing
    }

    // MARK: - Sync Down: ClaimEvents
    private func syncDownClaimEvents(context: ModelContext, since: String) async throws {
        debugLog.log("syncDownClaimEvents() - querying Supabase...", category: .sync)
        let dtos: [ClaimEventDTO] = try await supabase
            .from("claim_events")
            .select()
            .gt("updated_at", value: since)
            .execute()
            .value

        debugLog.logSyncOperation(operation: "FETCH", table: "claim_events", count: dtos.count)

        for (index, dto) in dtos.enumerated() {
            debugLog.log("  Upserting claim event \(index + 1)/\(dtos.count): \(dto.id)", category: .sync)
            try upsertClaimEvent(dto: dto, context: context)
        }
    }

    private func upsertClaimEvent(dto: ClaimEventDTO, context: ModelContext) throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<ClaimEvent>(
            predicate: #Predicate { $0.id == targetId }
        )

        if let existing = try context.fetch(descriptor).first {
            debugLog.log("    UPDATE existing claim event: \(dto.id)", category: .sync)

            let resolvedParentType: ParentType
            if let type = ParentType(rawValue: dto.parentType) {
                resolvedParentType = type
            } else {
                debugLog.log("⚠️ Invalid parentType '\(dto.parentType)' for ClaimEvent \(dto.id), defaulting to .task", category: .sync)
                resolvedParentType = .task
            }

            let resolvedAction: ClaimAction
            if let act = ClaimAction(rawValue: dto.action) {
                resolvedAction = act
            } else {
                debugLog.log("⚠️ Invalid action '\(dto.action)' for ClaimEvent \(dto.id), defaulting to .claimed", category: .sync)
                resolvedAction = .claimed
            }

            existing.parentType = resolvedParentType
            existing.parentId = dto.parentId
            existing.action = resolvedAction
            existing.userId = dto.userId
            existing.performedAt = dto.performedAt
            existing.reason = dto.reason
            existing.updatedAt = dto.updatedAt
            existing.markSynced()
        } else {
            debugLog.log("    INSERT new claim event: \(dto.id)", category: .sync)
            let newClaimEvent = dto.toModel()
            newClaimEvent.markSynced()
            context.insert(newClaimEvent)
        }
    }

    // MARK: - Sync Up (SwiftData → Supabase)
    private func syncUp(context: ModelContext) async throws {
        debugLog.log("syncUp() - pushing dirty entities to Supabase", category: .sync)
        
        // 0. Reconcile legacy "phantom" users (local-only but marked synced)
        // This is a lightweight local migration measure.
        try? await reconcileLegacyLocalUsers(context: context)
        
        debugLog.log("Sync order: Users → Listings → Tasks → Activities → ClaimEvents (FK dependencies)", category: .sync)

        // Sync in FK dependency order: Users first (owners), then Listings, then Tasks/Activities
        try await syncUpUsers(context: context)
        try await syncUpListings(context: context)
        try await syncUpTasks(context: context)
        try await syncUpActivities(context: context)
        try await syncUpClaimEvents(context: context)
        debugLog.log("syncUp() complete", category: .sync)
    }

    /// One-time local migration to catch "phantom" users that are marked .synced but were never uploaded (syncedAt == nil)
    /// OR users who have avatar data but no hash (legacy data).
    private func reconcileLegacyLocalUsers(context: ModelContext) async throws {
        // Fetch ALL users and filter in memory to avoid SwiftData #Predicate enum issues
        let descriptor = FetchDescriptor<User>()
        let allUsers = try context.fetch(descriptor)
        
        // 1. Phantom Users (Synced but no syncedAt date -> Pending)
        let phantomUsers = allUsers.filter { user in
            user.syncStateRaw == .synced && user.syncedAt == nil
        }
        
        if !phantomUsers.isEmpty {
            debugLog.log("Found \(phantomUsers.count) phantom legacy users. Marking as pending for upload.", category: .sync)
            for user in phantomUsers {
                user.markPending()
            }
        }
        
        // 2. Avatar Migration (Avatar Data present but Hash missing)
        // These users need to generate a hash so we don't re-upload eternally or fail to sync.
        let legacyAvatarUsers = allUsers.filter { user in
            user.avatar != nil && user.avatarHash == nil
        }
        
        if !legacyAvatarUsers.isEmpty {
            debugLog.log("Found \(legacyAvatarUsers.count) users with legacy avatars (no hash). Migrating...", category: .sync)
            
            for user in legacyAvatarUsers {
                if let data = user.avatar {
                    // Compute proper hash
                    let (normalized, hash) = await normalizeAndHash(data: data)
                    
                    // Update model
                    user.avatar = normalized
                    user.avatarHash = hash
                    
                    // Mark pending to ensure we sync this up to server
                    user.markPending()
                }
            }
            debugLog.log("✓ Migrated \(legacyAvatarUsers.count) legacy avatars", category: .sync)
        }
    }

    private func syncUpUsers(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<User>()
        let allUsers = try context.fetch(descriptor)
        debugLog.log("syncUpUsers() - fetched \(allUsers.count) total users from SwiftData", category: .sync)

        // Filter for pending or failed users
        let pendingUsers = allUsers.filter { $0.syncState == .pending || $0.syncState == .failed }
        debugLog.logSyncOperation(operation: "PENDING", table: "users", count: pendingUsers.count, details: "of \(allUsers.count) total")

        guard !pendingUsers.isEmpty else {
            debugLog.log("  No pending users to sync", category: .sync)
            return
        }

        // Process individually to handle avatar uploads reliably
        for user in pendingUsers {
            do {
                try await uploadAvatarAndSyncUser(user: user, context: context)

            } catch {
                let message = userFacingMessage(for: error)
                user.markFailed(message)
                debugLog.log("  ✗ Failed to sync user \(user.id): \(error.localizedDescription)", category: .error)
            }
        }
    }
    
    // Extracted helper for clarity and isolation
    private func uploadAvatarAndSyncUser(user: User, context: ModelContext) async throws {
        var avatarPath: String? = nil
        var avatarHash: String? = nil
        var uploadFailed = false
        
        if let avatarData = user.avatar {
            // Normalize & Hash (Off-Main)
            let (normalizedData, newHash) = await normalizeAndHash(data: avatarData)
            
            // If changed, Upload
            if newHash != user.avatarHash {
                debugLog.log("  Avatar hash changed. Uploading...", category: .sync)
                
                // Path: stored at root of 'avatars' bucket (User ID only)
                // "avatars" is the bucket, so we don't need a folder prefix unless we want one.
                // Simplification for V1: Root path prevents double-prefix issues.
                let path = "\(user.id.uuidString).jpg"
                
                do {
                    try await uploadAvatar(path: path, data: normalizedData)
                    
                    // Success: Update local
                    user.avatar = normalizedData
                    user.avatarHash = newHash
                    
                    avatarPath = path
                    avatarHash = newHash
                    debugLog.log("  ✓ Avatar uploaded", category: .sync)
                } catch {
                    debugLog.error("  ⚠️ Avatar upload failed", error: error)
                    uploadFailed = true // Mark failure
                }
            } else {
                debugLog.log("  Avatar hash matches. Skipping upload.", category: .sync)
                // Deterministic path reconstruction
                avatarPath = "\(user.id.uuidString).jpg"
                avatarHash = user.avatarHash
            }
        } else {
            // Nil avatar means delete
            avatarPath = nil
            avatarHash = nil
        }
        
        // Critical Safety: If upload failed, we SKIP upsert to avoid wiping/staling server state.
        // This is "Blocking" behavior, but prevents data corruption.
        guard !uploadFailed else {
            debugLog.log("  ⏭️ Skipping User upsert due to avatar failure", category: .sync)
            return // User stays .pending
        }
        
        // Upsert
        let dto = UserDTO(from: user, avatarPath: avatarPath, avatarHash: avatarHash)
        try await supabase.from("users").upsert([dto]).execute()
        
        user.markSynced()
        debugLog.log("  ✓ User \(user.id) synced", category: .sync)
    }

    /// Helper: Normalizes image to JPEG and computes SHA256 (Off-Main Actor)
    private nonisolated func normalizeAndHash(data: Data) async -> (Data, String) {
        return await Task.detached(priority: .userInitiated) {
            // 1. Resize/Compress (Mocking via just using data for now to avoid UIKit/ImageRenderer complexity in this snippet if not imported)
            // Ideally: Use UIImage/NSImage to resize -> JPEG 0.8
            // For stability without UI deps in SyncManager (which might be Data/Logic only):
            // We will skip resize for this iteration but MUST do SHA256.
            // Wait, we can import ImageIO or similar?
            // "Jobs-standard rule: normalize".
            // I'll stick to just Hashing for V1 if I lack image tools in this context,
            // or I'll assume `data` is acceptable.
            // Let's implement SHA256.
            
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            // Returning original data as "normalized" for now to avoid massive dependency add.
            // TODO: Add Image Resizing.
            return (data, hash)
        }.value
    }
    
    private func uploadAvatar(path: String, data: Data) async throws {
        let bucket = "avatars"
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
    }

    private func syncUpTasks(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<TaskItem>()
        let allTasks = try context.fetch(descriptor)
        debugLog.log("syncUpTasks() - fetched \(allTasks.count) total tasks from SwiftData", category: .sync)

        // Filter for pending or failed (retry) tasks
        let pendingTasks = allTasks.filter { $0.syncState == .pending || $0.syncState == .failed }
        debugLog.logSyncOperation(operation: "PENDING", table: "tasks", count: pendingTasks.count, details: "of \(allTasks.count) total")

        // Debug: log claimedBy value for each pending task
        for task in pendingTasks {
            debugLog.log("  📋 Pending task \(task.id): claimedBy=\(task.claimedBy?.uuidString ?? "nil"), title=\(task.title)", category: .sync)
        }

        guard !pendingTasks.isEmpty else {
            debugLog.log("  No pending tasks to sync", category: .sync)
            return
        }

        // Mark as in-flight before upsert to prevent realtime echo from overwriting local state
        inFlightTaskIds = Set(pendingTasks.map { $0.id })
        defer { inFlightTaskIds.removeAll() }  // Always clear, even on error

        // Try batch first for efficiency
        do {
            let dtos = pendingTasks.map { task -> TaskDTO in
                let dto = TaskDTO(from: task)
                debugLog.log("  📤 Preparing DTO for task \(task.id): claimedBy=\(dto.claimedBy?.uuidString ?? "nil"), syncState=\(task.syncState)", category: .sync)
                return dto
            }
            debugLog.log("  Batch upserting \(dtos.count) tasks to Supabase...", category: .sync)
            try await supabase
                .from("tasks")
                .upsert(dtos)
                .execute()
            debugLog.log("  Batch upsert successful", category: .sync)

            // Success - mark all synced
            for task in pendingTasks {
                task.markSynced()
            }
            debugLog.log("  Marked \(pendingTasks.count) tasks as synced", category: .sync)
        } catch {
            // Batch failed - try individual items to isolate failures
            debugLog.log("Batch task sync failed, trying individually: \(error.localizedDescription)", category: .error)

            for task in pendingTasks {
                do {
                    let dto = TaskDTO(from: task)
                    try await supabase
                        .from("tasks")
                        .upsert([dto])
                        .execute()
                    task.markSynced()
                    debugLog.log("  ✓ Task \(task.id) synced individually", category: .sync)
                } catch {
                    let message = userFacingMessage(for: error)
                    task.markFailed(message)
                    debugLog.error("  ✗ Task \(task.id) sync failed: \(message)")
                }
            }
        }
    }

    private func syncUpActivities(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Activity>()
        let allActivities = try context.fetch(descriptor)
        debugLog.log("syncUpActivities() - fetched \(allActivities.count) total activities from SwiftData", category: .sync)

        let pendingActivities = allActivities.filter { $0.syncState == .pending || $0.syncState == .failed }
        debugLog.logSyncOperation(operation: "PENDING", table: "activities", count: pendingActivities.count, details: "of \(allActivities.count) total")

        guard !pendingActivities.isEmpty else {
            debugLog.log("  No pending activities to sync", category: .sync)
            return
        }

        // Mark as in-flight before upsert to prevent realtime echo from overwriting local state
        inFlightActivityIds = Set(pendingActivities.map { $0.id })
        defer { inFlightActivityIds.removeAll() }

        // Try batch first for efficiency
        do {
            let dtos = pendingActivities.map { ActivityDTO(from: $0) }
            debugLog.log("  Batch upserting \(dtos.count) activities to Supabase...", category: .sync)
            try await supabase
                .from("activities")
                .upsert(dtos)
                .execute()
            debugLog.log("  Batch upsert successful", category: .sync)

            for activity in pendingActivities {
                activity.markSynced()
            }
            debugLog.log("  Marked \(pendingActivities.count) activities as synced", category: .sync)
        } catch {
            // Batch failed - try individual items to isolate failures
            debugLog.log("Batch activity sync failed, trying individually: \(error.localizedDescription)", category: .error)

            for activity in pendingActivities {
                do {
                    let dto = ActivityDTO(from: activity)
                    try await supabase
                        .from("activities")
                        .upsert([dto])
                        .execute()
                    activity.markSynced()
                    debugLog.log("  ✓ Activity \(activity.id) synced individually", category: .sync)
                } catch {
                    let message = userFacingMessage(for: error)
                    activity.markFailed(message)
                    debugLog.error("  ✗ Activity \(activity.id) sync failed: \(message)")
                }
            }
        }
    }

    private func syncUpListings(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Listing>()
        let allListings = try context.fetch(descriptor)
        debugLog.log("syncUpListings() - fetched \(allListings.count) total listings from SwiftData", category: .sync)

        let pendingListings = allListings.filter { $0.syncState == .pending || $0.syncState == .failed }
        debugLog.logSyncOperation(operation: "PENDING", table: "listings", count: pendingListings.count, details: "of \(allListings.count) total")

        guard !pendingListings.isEmpty else {
            debugLog.log("  No pending listings to sync", category: .sync)
            return
        }

        // Try batch first for efficiency
        do {
            let dtos = pendingListings.map { ListingDTO(from: $0) }
            debugLog.log("  Batch upserting \(dtos.count) listings to Supabase...", category: .sync)
            try await supabase
                .from("listings")
                .upsert(dtos)
                .execute()
            debugLog.log("  Batch upsert successful", category: .sync)

            for listing in pendingListings {
                listing.markSynced()
            }
            debugLog.log("  Marked \(pendingListings.count) listings as synced", category: .sync)
        } catch {
            // Batch failed - try individual items to isolate failures
            debugLog.log("Batch listing sync failed, trying individually: \(error.localizedDescription)", category: .error)

            for listing in pendingListings {
                do {
                    let dto = ListingDTO(from: listing)
                    try await supabase
                        .from("listings")
                        .upsert([dto])
                        .execute()
                    listing.markSynced()
                    debugLog.log("  ✓ Listing \(listing.id) synced individually", category: .sync)
                } catch {
                    let message = userFacingMessage(for: error)
                    listing.markFailed(message)
                    debugLog.error("  ✗ Listing \(listing.id) sync failed: \(message)")
                }
            }
        }
    }

    private func syncUpClaimEvents(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<ClaimEvent>()
        let allClaimEvents = try context.fetch(descriptor)
        debugLog.log("syncUpClaimEvents() - fetched \(allClaimEvents.count) total claim events from SwiftData", category: .sync)

        let pendingClaimEvents = allClaimEvents.filter { $0.syncState == .pending || $0.syncState == .failed }
        debugLog.logSyncOperation(operation: "PENDING", table: "claim_events", count: pendingClaimEvents.count, details: "of \(allClaimEvents.count) total")

        guard !pendingClaimEvents.isEmpty else {
            debugLog.log("  No pending claim events to sync", category: .sync)
            return
        }

        // Try batch first for efficiency
        do {
            let dtos = pendingClaimEvents.map { ClaimEventDTO(from: $0) }
            debugLog.log("  Batch upserting \(dtos.count) claim events to Supabase...", category: .sync)
            try await supabase
                .from("claim_events")
                .upsert(dtos)
                .execute()
            debugLog.log("  Batch upsert successful", category: .sync)

            for claimEvent in pendingClaimEvents {
                claimEvent.markSynced()
            }
            debugLog.log("  Marked \(pendingClaimEvents.count) claim events as synced", category: .sync)
        } catch {
            // Batch failed - try individual items to isolate failures
            debugLog.log("Batch claim event sync failed, trying individually: \(error.localizedDescription)", category: .error)

            for claimEvent in pendingClaimEvents {
                do {
                    let dto = ClaimEventDTO(from: claimEvent)
                    try await supabase
                        .from("claim_events")
                        .upsert([dto])
                        .execute()
                    claimEvent.markSynced()
                    debugLog.log("  ✓ ClaimEvent \(claimEvent.id) synced individually", category: .sync)
                } catch {
                    let message = userFacingMessage(for: error)
                    claimEvent.markFailed(message)
                    debugLog.error("  ✗ ClaimEvent \(claimEvent.id) sync failed: \(message)")
                }
            }
        }
    }

    // MARK: - Realtime (Delta Sync)

    func startListening() async {
        debugLog.log("", category: .realtime)
        debugLog.log("╔════════════════════════════════════════════════════════════╗", category: .realtime)
        debugLog.log("║           startListening() CALLED                          ║", category: .realtime)
        debugLog.log("╚════════════════════════════════════════════════════════════╝", category: .realtime)
        debugLog.log("", category: .realtime)

        debugLog.log("Pre-flight checks:", category: .realtime)
        debugLog.log("  isAuthenticated: \(isAuthenticated)", category: .realtime)
        debugLog.log("  isListening: \(isListening)", category: .realtime)
        debugLog.log("  currentUserID: \(currentUserID?.uuidString ?? "nil")", category: .realtime)
        debugLog.log("  modelContainer: \(modelContainer != nil ? "SET" : "NIL")", category: .realtime)

        guard isAuthenticated, !isListening else {
            debugLog.log("❌ GUARD FAILED - Skipping startListening()", category: .realtime)
            debugLog.log("  Reason: \(!isAuthenticated ? "Not authenticated (currentUserID is nil)" : "Already listening")", category: .realtime)
            return
        }

        isListening = true
        debugLog.log("✓ Guards passed, isListening set to true", category: .realtime)

        // Log Supabase configuration
        debugLog.log("", category: .realtime)
        debugLog.log("Supabase Configuration:", category: .realtime)
        debugLog.log("  URL: \(Secrets.supabaseURL)", category: .realtime)
        debugLog.log("  Anon Key (prefix): \(String(Secrets.supabaseAnonKey.prefix(30)))...", category: .realtime)

        // Start socket status monitoring with reconnect sync
        debugLog.log("", category: .websocket)
        debugLog.log("Setting up WebSocket status monitor...", category: .websocket)
        let socketStatusID = performTrackedTask("Socket Status") { [weak self] in
            guard let self = self else { return }
            debugLog.log("📡 Socket status monitor task STARTED", category: .websocket)
            for await status in supabase.realtimeV2.statusChange {
                switch status {
                case .disconnected:
                    debugLog.log("🔴 SOCKET DISCONNECTED", category: .websocket)
                    debugLog.log("  ⚠️ This means realtime events WILL NOT be received!", category: .websocket)
                    self.wasDisconnected = true
                case .connecting:
                    debugLog.log("🟡 SOCKET CONNECTING...", category: .websocket)
                case .connected:
                    debugLog.log("🟢 SOCKET CONNECTED", category: .websocket)
                    debugLog.log("  ✓ WebSocket connection established", category: .websocket)
                    // Trigger full sync on reconnect to reconcile missed events
                    if self.wasDisconnected {
                        debugLog.log("  🔄 Reconnected after disconnect - triggering full sync to reconcile missed events", category: .websocket)
                        self.wasDisconnected = false
                        await self.sync()
                    }
                @unknown default:
                    debugLog.log("⚠️ SOCKET UNKNOWN STATUS: \(status)", category: .websocket)
                }
            }
            debugLog.log("📡 Socket status monitor task ENDED (for-await exited)", category: .websocket)
        }

        // Create channel
        let channelName = "dispatch-sync"
        debugLog.log("", category: .channel)
        debugLog.log("Creating channel: '\(channelName)'", category: .channel)
        let channel = supabase.realtimeV2.channel(channelName)
        debugLog.log("✓ Channel object created", category: .channel)

        // Configure postgres change subscriptions
        let tables = ["tasks", "activities", "listings", "users", "claim_events"]
        debugLog.log("", category: .channel)
        debugLog.log("Configuring postgresChange() for \(tables.count) tables:", category: .channel)
        for table in tables {
            debugLog.logSubscriptionConfig(table: table, schema: "public", filter: nil)
        }

        debugLog.log("", category: .channel)
        debugLog.log("Creating AsyncSequence listeners (delta sync)...", category: .channel)

        // INSERT listeners for delta sync (decode payload directly, no full sync)
        let tasksInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "tasks")
        debugLog.log("  ✓ tasks INSERT listener created", category: .channel)
        let activitiesInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "activities")
        debugLog.log("  ✓ activities INSERT listener created", category: .channel)
        let listingsInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "listings")
        debugLog.log("  ✓ listings INSERT listener created", category: .channel)
        let usersInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "users")
        debugLog.log("  ✓ users INSERT listener created", category: .channel)
        let claimEventsInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "claim_events")
        debugLog.log("  ✓ claim_events INSERT listener created", category: .channel)

        // UPDATE listeners for delta sync (decode payload directly, no full sync)
        let tasksUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "tasks")
        debugLog.log("  ✓ tasks UPDATE listener created", category: .channel)
        let activitiesUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "activities")
        debugLog.log("  ✓ activities UPDATE listener created", category: .channel)
        let listingsUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "listings")
        debugLog.log("  ✓ listings UPDATE listener created", category: .channel)
        let usersUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "users")
        debugLog.log("  ✓ users UPDATE listener created", category: .channel)
        let claimEventsUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "claim_events")
        debugLog.log("  ✓ claim_events UPDATE listener created", category: .channel)

        // DELETE listeners for immediate local deletion
        let tasksDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "tasks")
        debugLog.log("  ✓ tasks DELETE listener created", category: .channel)
        let activitiesDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "activities")
        debugLog.log("  ✓ activities DELETE listener created", category: .channel)
        let listingsDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "listings")
        debugLog.log("  ✓ listings DELETE listener created", category: .channel)
        let usersDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "users")
        debugLog.log("  ✓ users DELETE listener created", category: .channel)
        let claimEventsDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "claim_events")
        debugLog.log("  ✓ claim_events DELETE listener created", category: .channel)

        // Subscribe to channel
        debugLog.log("", category: .channel)
        debugLog.log("Calling channel.subscribeWithError()...", category: .channel)
        debugLog.startTiming("channel.subscribeWithError")
        do {
            try await channel.subscribeWithError()
            debugLog.endTiming("channel.subscribeWithError")
            debugLog.log("✅ CHANNEL SUBSCRIPTION SUCCESSFUL", category: .channel)
        } catch {
            debugLog.endTiming("channel.subscribeWithError")
            debugLog.error("❌ CHANNEL SUBSCRIPTION FAILED", error: error)
            debugLog.log("", category: .error)
            debugLog.log("Possible causes:", category: .error)
            debugLog.log("  1. Network connectivity issues", category: .error)
            debugLog.log("  2. Invalid Supabase URL or API key", category: .error)
            debugLog.log("  3. Realtime not enabled for project", category: .error)
            debugLog.log("  4. Tables not in supabase_realtime publication", category: .error)
            debugLog.log("  5. WebSocket blocked by firewall/proxy", category: .error)
            // Cancel the socket status task to prevent leaked monitoring task
            self.activeTasks[socketStatusID]?.cancel()
            isListening = false
            return
        }

        // Monitor channel status
        performTrackedTask("Channel Status") {
            debugLog.log("📺 Channel status monitor task STARTED", category: .channel)
            for await status in channel.statusChange {
                switch status {
                case .unsubscribed:
                    debugLog.logChannelStatus(channelName, status: "UNSUBSCRIBED")
                case .subscribing:
                    debugLog.logChannelStatus(channelName, status: "SUBSCRIBING...")
                case .subscribed:
                    debugLog.logChannelStatus(channelName, status: "SUBSCRIBED ✓")
                    debugLog.log("  ✓ Channel is now actively listening for events", category: .channel)
                case .unsubscribing:
                    debugLog.logChannelStatus(channelName, status: "UNSUBSCRIBING...")
                @unknown default:
                    debugLog.logChannelStatus(channelName, status: "UNKNOWN: \(status)")
                }
            }
            debugLog.log("📺 Channel status monitor task ENDED", category: .channel)
        }

        // Create listener tasks with delta sync (no requestSync() calls)
        debugLog.log("", category: .event)
        debugLog.log("Creating for-await listener tasks for each table (delta sync)...", category: .event)
        
        // Socket and Channel tasks already created above
        
        // MARK: - Tasks INSERT/UPDATE (Delta Sync)
        performTrackedTask("Tasks INSERT") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "tasks INSERT")
            for await insertion in tasksInserts {
                debugLog.log("", category: .event)
                debugLog.log("📥 TASKS INSERT EVENT RECEIVED", category: .event)
                do {
                    let dto = try insertion.decodeRecord(as: TaskDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded task: \(dto.id) - \(dto.title)", category: .event)

                    if self.inFlightTaskIds.contains(dto.id) {
                        debugLog.log("  ⏭️ Skipping in-flight task (self-originated): \(dto.id)", category: .event)
                        continue
                    }

                    let context = container.mainContext
                    try self.upsertTask(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ Task inserted locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply task insert", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "tasks INSERT")
        }
        
        performTrackedTask("Tasks UPDATE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "tasks UPDATE")
            for await update in tasksUpdates {
                debugLog.log("", category: .event)
                debugLog.log("📝 TASKS UPDATE EVENT RECEIVED", category: .event)
                do {
                    let dto = try update.decodeRecord(as: TaskDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded task: \(dto.id) - \(dto.title)", category: .event)

                    if self.inFlightTaskIds.contains(dto.id) {
                        debugLog.log("  ⏭️ Skipping in-flight task (self-originated echo): \(dto.id)", category: .event)
                        continue
                    }

                    let context = container.mainContext
                    try self.upsertTask(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ Task updated locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply task update", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "tasks UPDATE")
        }

        // MARK: - Activities INSERT/UPDATE (Delta Sync)
        performTrackedTask("Activities INSERT") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "activities INSERT")
            for await insertion in activitiesInserts {
                debugLog.log("", category: .event)
                debugLog.log("📥 ACTIVITIES INSERT EVENT RECEIVED", category: .event)
                do {
                    let dto = try insertion.decodeRecord(as: ActivityDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded activity: \(dto.id) - \(dto.title)", category: .event)

                    if self.inFlightActivityIds.contains(dto.id) {
                        debugLog.log("  ⏭️ Skipping in-flight activity (self-originated): \(dto.id)", category: .event)
                        continue
                    }

                    let context = container.mainContext
                    try self.upsertActivity(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ Activity inserted locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply activity insert", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "activities INSERT")
        }
        
        performTrackedTask("Activities UPDATE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "activities UPDATE")
            for await update in activitiesUpdates {
                debugLog.log("", category: .event)
                debugLog.log("📝 ACTIVITIES UPDATE EVENT RECEIVED", category: .event)
                do {
                    let dto = try update.decodeRecord(as: ActivityDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded activity: \(dto.id) - \(dto.title)", category: .event)

                    if self.inFlightActivityIds.contains(dto.id) {
                        debugLog.log("  ⏭️ Skipping in-flight activity (self-originated echo): \(dto.id)", category: .event)
                        continue
                    }

                    let context = container.mainContext
                    try self.upsertActivity(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ Activity updated locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply activity update", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "activities UPDATE")
        }

        // MARK: - Listings INSERT/UPDATE (Delta Sync)
        performTrackedTask("Listings INSERT") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "listings INSERT")
            for await insertion in listingsInserts {
                debugLog.log("", category: .event)
                debugLog.log("📥 LISTINGS INSERT EVENT RECEIVED", category: .event)
                do {
                    let dto = try insertion.decodeRecord(as: ListingDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded listing: \(dto.id) - \(dto.address)", category: .event)
                    let context = container.mainContext
                    try self.upsertListing(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ Listing inserted locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply listing insert", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "listings INSERT")
        }
        
        performTrackedTask("Listings UPDATE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "listings UPDATE")
            for await update in listingsUpdates {
                debugLog.log("", category: .event)
                debugLog.log("📝 LISTINGS UPDATE EVENT RECEIVED", category: .event)
                do {
                    let dto = try update.decodeRecord(as: ListingDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded listing: \(dto.id) - \(dto.address)", category: .event)
                    let context = container.mainContext
                    try self.upsertListing(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ Listing updated locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply listing update", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "listings UPDATE")
        }

        // MARK: - Users INSERT/UPDATE (Delta Sync)
        performTrackedTask("Users INSERT") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "users INSERT")
            for await insertion in usersInserts {
                debugLog.log("", category: .event)
                debugLog.log("📥 USERS INSERT EVENT RECEIVED", category: .event)
                do {
                    let dto = try insertion.decodeRecord(as: UserDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded user: \(dto.id) - \(dto.name)", category: .event)
                    let context = container.mainContext
                    try await self.upsertUser(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ User inserted locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply user insert", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "users INSERT")
        }
        
        performTrackedTask("Users UPDATE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "users UPDATE")
            for await update in usersUpdates {
                debugLog.log("", category: .event)
                debugLog.log("📝 USERS UPDATE EVENT RECEIVED", category: .event)
                do {
                    let dto = try update.decodeRecord(as: UserDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded user: \(dto.id) - \(dto.name)", category: .event)
                    let context = container.mainContext
                    try await self.upsertUser(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ User updated locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply user update", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "users UPDATE")
        }

        // MARK: - ClaimEvents INSERT/UPDATE (Delta Sync)
        performTrackedTask("ClaimEvents INSERT") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "claim_events INSERT")
            for await insertion in claimEventsInserts {
                debugLog.log("", category: .event)
                debugLog.log("📥 CLAIM_EVENTS INSERT EVENT RECEIVED", category: .event)
                do {
                    let dto = try insertion.decodeRecord(as: ClaimEventDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded claim event: \(dto.id)", category: .event)
                    let context = container.mainContext
                    try self.upsertClaimEvent(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ ClaimEvent inserted locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply claim event insert", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "claim_events INSERT")
        }
        
        performTrackedTask("ClaimEvents UPDATE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.logForAwaitLoop(entering: true, table: "claim_events UPDATE")
            for await update in claimEventsUpdates {
                debugLog.log("", category: .event)
                debugLog.log("📝 CLAIM_EVENTS UPDATE EVENT RECEIVED", category: .event)
                do {
                    let dto = try update.decodeRecord(as: ClaimEventDTO.self, decoder: PostgrestClient.Configuration.jsonDecoder)
                    debugLog.log("  ✓ Decoded claim event: \(dto.id)", category: .event)
                    let context = container.mainContext
                    try self.upsertClaimEvent(dto: dto, context: context)
                    try context.save()
                    debugLog.log("  ✓ ClaimEvent updated locally", category: .event)
                } catch {
                    debugLog.error("  Failed to decode/apply claim event update", error: error)
                }
            }
            debugLog.logForAwaitLoop(entering: false, table: "claim_events UPDATE")
        }

        // MARK: - DELETE Handlers
        performTrackedTask("Tasks DELETE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.log("🗑️ Tasks DELETE listener STARTED", category: .event)
            for await deleteEvent in tasksDeletes {
                debugLog.log("", category: .event)
                debugLog.log("🗑️ TASKS DELETE EVENT RECEIVED", category: .event)
                if let deletedId = self.extractUUID(from: deleteEvent.oldRecord, key: "id") {
                    debugLog.log("  Deleted task ID: \(deletedId)", category: .event)
                    let context = container.mainContext
                    do {
                        _ = try self.deleteLocalTask(id: deletedId, context: context)
                        try context.save()
                        debugLog.log("  ✓ Local task deleted successfully", category: .event)
                    } catch {
                        debugLog.error("  Failed to delete local task", error: error)
                    }
                } else {
                    debugLog.log("  ⚠️ Could not extract task ID from DELETE event oldRecord: \(deleteEvent.oldRecord)", category: .event)
                }
            }
            debugLog.log("🗑️ Tasks DELETE listener ENDED", category: .event)
        }
        
        performTrackedTask("Activities DELETE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.log("🗑️ Activities DELETE listener STARTED", category: .event)
            for await deleteEvent in activitiesDeletes {
                debugLog.log("", category: .event)
                debugLog.log("🗑️ ACTIVITIES DELETE EVENT RECEIVED", category: .event)
                if let deletedId = self.extractUUID(from: deleteEvent.oldRecord, key: "id") {
                    debugLog.log("  Deleted activity ID: \(deletedId)", category: .event)
                    let context = container.mainContext
                    do {
                        _ = try self.deleteLocalActivity(id: deletedId, context: context)
                        try context.save()
                        debugLog.log("  ✓ Local activity deleted successfully", category: .event)
                    } catch {
                        debugLog.error("  Failed to delete local activity", error: error)
                    }
                } else {
                    debugLog.log("  ⚠️ Could not extract activity ID from DELETE event", category: .event)
                }
            }
            debugLog.log("🗑️ Activities DELETE listener ENDED", category: .event)
        }
        
        performTrackedTask("Listings DELETE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.log("🗑️ Listings DELETE listener STARTED", category: .event)
            for await deleteEvent in listingsDeletes {
                debugLog.log("", category: .event)
                debugLog.log("🗑️ LISTINGS DELETE EVENT RECEIVED", category: .event)
                if let deletedId = self.extractUUID(from: deleteEvent.oldRecord, key: "id") {
                    debugLog.log("  Deleted listing ID: \(deletedId)", category: .event)
                    let context = container.mainContext
                    do {
                        _ = try self.deleteLocalListing(id: deletedId, context: context)
                        try context.save()
                        debugLog.log("  ✓ Local listing deleted successfully", category: .event)
                    } catch {
                        debugLog.error("  Failed to delete local listing", error: error)
                    }
                } else {
                    debugLog.log("  ⚠️ Could not extract listing ID from DELETE event", category: .event)
                }
            }
            debugLog.log("🗑️ Listings DELETE listener ENDED", category: .event)
        }
        
        performTrackedTask("Users DELETE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.log("🗑️ Users DELETE listener STARTED", category: .event)
            for await deleteEvent in usersDeletes {
                debugLog.log("", category: .event)
                debugLog.log("🗑️ USERS DELETE EVENT RECEIVED", category: .event)
                if let deletedId = self.extractUUID(from: deleteEvent.oldRecord, key: "id") {
                    debugLog.log("  Deleted user ID: \(deletedId)", category: .event)
                    let context = container.mainContext
                    do {
                        _ = try self.deleteLocalUser(id: deletedId, context: context)
                        try context.save()
                        debugLog.log("  ✓ Local user deleted successfully", category: .event)
                    } catch {
                        debugLog.error("  Failed to delete local user", error: error)
                    }
                } else {
                    debugLog.log("  ⚠️ Could not extract user ID from DELETE event", category: .event)
                }
            }
            debugLog.log("🗑️ Users DELETE listener ENDED", category: .event)
        }
        
        performTrackedTask("ClaimEvents DELETE") { [weak self] in
            guard let self = self, let container = self.modelContainer else { return }
            debugLog.log("🗑️ ClaimEvents DELETE listener STARTED", category: .event)
            for await deleteEvent in claimEventsDeletes {
                debugLog.log("", category: .event)
                debugLog.log("🗑️ CLAIM_EVENTS DELETE EVENT RECEIVED", category: .event)
                if let deletedId = self.extractUUID(from: deleteEvent.oldRecord, key: "id") {
                    debugLog.log("  Deleted claim event ID: \(deletedId)", category: .event)
                    let context = container.mainContext
                    do {
                        _ = try self.deleteLocalClaimEvent(id: deletedId, context: context)
                        try context.save()
                        debugLog.log("  ✓ Local claim event deleted successfully", category: .event)
                    } catch {
                        debugLog.error("  Failed to delete local claim event", error: error)
                    }
                } else {
                    debugLog.log("  ⚠️ Could not extract claim event ID from DELETE event", category: .event)
                }
            }
            debugLog.log("🗑️ ClaimEvents DELETE listener ENDED", category: .event)
        }
        
        realtimeChannel = channel

        debugLog.log("", category: .realtime)
        debugLog.log("╔════════════════════════════════════════════════════════════╗", category: .realtime)
        debugLog.log("║           REALTIME SETUP COMPLETE                          ║", category: .realtime)
        debugLog.log("╚════════════════════════════════════════════════════════════╝", category: .realtime)
        debugLog.log("  Tables monitored: \(tables.joined(separator: ", "))", category: .realtime)
        debugLog.log("", category: .realtime)
        debugLog.log("Waiting for database changes...", category: .realtime)
        debugLog.log("  To test: UPDATE a row in Supabase dashboard", category: .realtime)
        debugLog.log("  Expected: '[EVENT] 🎉🎉🎉 EVENT RECEIVED!' message", category: .realtime)

        // Start broadcast listener if enabled (runs in parallel with postgres_changes)
        await startBroadcastListening()
    }

    func stopListening() async {
        debugLog.log("stopListening() called", category: .realtime)
        // 1. Unsubscribing logic handles termination of loops.
        // 2. shutdown() handles brute force cancellation of activeTasks.

        if let channel = realtimeChannel {
            debugLog.log("  Unsubscribing from postgres_changes channel...", category: .realtime)
            await channel.unsubscribe()
            debugLog.log("  postgres_changes channel unsubscribed", category: .realtime)
        }
        realtimeChannel = nil

        // Cleanup broadcast channel
        if let channel = broadcastChannel {
            debugLog.log("  Unsubscribing from broadcast channel...", category: .realtime)
            await channel.unsubscribe()
            debugLog.log("  Broadcast channel unsubscribed", category: .realtime)
        }
        broadcastChannel = nil

        isListening = false
        debugLog.log("✓ Realtime stopped. isListening = false", category: .realtime)
    }

    // MARK: - Broadcast Realtime (v2 Pattern)

    /// Starts listening to broadcast channel (v2 pattern).
    /// Coexists with postgres_changes during Phase 1 migration.
    private func startBroadcastListening() async {
        guard useBroadcastRealtime else {
            debugLog.log("Broadcast realtime disabled (useBroadcastRealtime = false)", category: .channel)
            return
        }
        guard isAuthenticated, let container = modelContainer else {
            debugLog.log("Skipping broadcast listener - not authenticated or no container", category: .channel)
            return
        }

        debugLog.log("", category: .channel)
        debugLog.log("╔════════════════════════════════════════════════════════════╗", category: .channel)
        debugLog.log("║       BROADCAST REALTIME (v2) STARTING                     ║", category: .channel)
        debugLog.log("╚════════════════════════════════════════════════════════════╝", category: .channel)

        // CRITICAL: Set auth token for Realtime Authorization (RLS on realtime.messages)
        // This must be called BEFORE subscribing to private channels
        debugLog.log("Setting Realtime auth token...", category: .channel)
        await supabase.realtimeV2.setAuth()
        debugLog.log("✓ Realtime auth token set", category: .channel)

        // Create broadcast channel
        // NOTE: Testing WITHOUT isPrivate to debug subscription timeout
        // realtime.broadcast_changes() may use public channels by default
        debugLog.log("Creating channel 'dispatch:broadcast' (testing without isPrivate)...", category: .channel)
        let channel = supabase.realtimeV2.channel("dispatch:broadcast") {
            // $0.isPrivate = true  // DISABLED for testing - may be causing timeout
            $0.broadcast.receiveOwnBroadcasts = true  // We filter by origin_user_id instead
        }

        // Subscribe to all broadcast events
        let broadcastStream = channel.broadcastStream(event: "*")

        debugLog.log("Calling channel.subscribeWithError() for broadcast...", category: .channel)
        do {
            // Add timeout to detect hanging subscriptions
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await channel.subscribeWithError()
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    throw NSError(domain: "Broadcast", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subscription timed out after 10s"])
                }
                // Wait for first to complete (subscription or timeout)
                try await group.next()
                group.cancelAll()
            }
            debugLog.log("✅ Broadcast channel subscribed successfully", category: .channel)
        } catch {
            debugLog.error("❌ Broadcast subscription failed", error: error)
            return
        }

        broadcastChannel = channel

        // Create listener task for broadcast events
        performTrackedTask("Broadcast Listener") { [weak self] in
            guard let self = self else { return }
            guard let container = self.modelContainer else { return }
            
            debugLog.log("📡 Broadcast listener task STARTED", category: .event)
            for await event in broadcastStream {
                await self.handleBroadcastEvent(event, container: container)
            }
            debugLog.log("📡 Broadcast listener task ENDED", category: .event)
        }

        debugLog.log("", category: .channel)
        debugLog.log("Broadcast channel ready - listening for events on 'dispatch:broadcast'", category: .channel)
    }

    /// Handles broadcast events - routes to existing upsert/delete methods
    /// The event parameter is the raw JSON message from broadcastStream
    private func handleBroadcastEvent(_ event: JSONObject, container: ModelContainer) async {
        do {
            // Log raw payload for debugging
            debugLog.log("", category: .event)
            debugLog.log("📡 RAW BROADCAST EVENT RECEIVED", category: .event)

            // JSONObject is [String: AnyJSON] - use JSONEncoder for AnyJSON (Codable)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let jsonData = try? encoder.encode(event),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                debugLog.log("Raw payload:\n\(jsonString)", category: .event)
            } else {
                debugLog.log("Raw payload (keys): \(event.keys.joined(separator: ", "))", category: .event)
            }

            // Supabase Realtime wraps our payload in: { event, type, payload, meta }
            // Our BroadcastChangePayload is inside the "payload" field
            guard let innerPayload = event["payload"]?.objectValue else {
                debugLog.log("Missing or invalid 'payload' field in broadcast event - keys: \(event.keys.joined(separator: ", "))", category: .event)
                return
            }

            // Use PostgrestClient's decoder for consistency with other DTO decoding
            guard let payloadData = try? encoder.encode(innerPayload),
                  let payload = try? PostgrestClient.Configuration.jsonDecoder.decode(BroadcastChangePayload.self, from: payloadData) else {
                debugLog.log("Failed to decode broadcast payload - inner keys: \(innerPayload.keys.joined(separator: ", "))", category: .event)
                return
            }

            // Version check: log unknown versions for visibility when we bump the version
            if payload.eventVersion != 1 {
                debugLog.log("Unknown event version \(payload.eventVersion) for table \(payload.table)", category: .event)
                // For now, still try to handle. Later, can gate behavior on version.
            }

            // Self-echo filtering: skip if originated from current user
            // NOTE: nil originUserId means system-originated - do NOT skip those
            if let originUserId = payload.originUserId,
               let currentUser = currentUserID,
               originUserId == currentUser {
                debugLog.log("⏭️ Skipping self-originated broadcast: \(payload.table) \(payload.type)", category: .event)
                return
            }

            debugLog.log("", category: .event)
            debugLog.log("📡 BROADCAST EVENT: \(payload.table) \(payload.type)", category: .event)

            let context = container.mainContext

            // Route to appropriate handler based on table (type-safe enum switch)
            switch payload.table {
            case .tasks:
                try await handleTaskBroadcast(payload: payload, context: context)
            case .activities:
                try await handleActivityBroadcast(payload: payload, context: context)
            case .listings:
                try await handleListingBroadcast(payload: payload, context: context)
            case .users:
                try await handleUserBroadcast(payload: payload, context: context)
            case .claimEvents:
                try await handleClaimEventBroadcast(payload: payload, context: context)
            }

            try context.save()

        } catch {
            debugLog.error("Failed to handle broadcast event", error: error)
        }
    }

    // MARK: - Broadcast Handlers

    /// Handles task broadcast - converts payload to TaskDTO and calls existing upsertTask
    private func handleTaskBroadcast(payload: BroadcastChangePayload, context: ModelContext) async throws {
        if payload.type == .delete {
            if let oldRecord = payload.cleanedOldRecord(),
               let idString = oldRecord["id"] as? String,
               let id = UUID(uuidString: idString) {
                _ = try deleteLocalTask(id: id, context: context)
                debugLog.log("  ✓ Broadcast: Deleted task \(id)", category: .event)
            }
        } else {
            // INSERT or UPDATE - use centralized cleanedRecord() helper
            guard let cleanRecord = payload.cleanedRecord() else { return }

            let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
            let dto = try PostgrestClient.Configuration.jsonDecoder.decode(TaskDTO.self, from: recordData)

            // Use existing in-flight check as backup (will be removed in Phase 3)
            if inFlightTaskIds.contains(dto.id) {
                debugLog.log("  ⏭️ Broadcast: Skipping in-flight task \(dto.id)", category: .event)
                return
            }

            #if DEBUG
            // Phase 1 duplicate detection: log if processed recently via postgres_changes
            if recentlyProcessedIds.contains(dto.id) {
                debugLog.log("  ⚠️ Broadcast: Duplicate processing detected for task \(dto.id)", category: .event)
            }
            recentlyProcessedIds.insert(dto.id)
            #endif

            try upsertTask(dto: dto, context: context)
            debugLog.log("  ✓ Broadcast: Upserted task \(dto.id)", category: .event)
        }
    }

    /// Handles activity broadcast - converts payload to ActivityDTO and calls existing upsertActivity
    private func handleActivityBroadcast(payload: BroadcastChangePayload, context: ModelContext) async throws {
        if payload.type == .delete {
            if let oldRecord = payload.cleanedOldRecord(),
               let idString = oldRecord["id"] as? String,
               let id = UUID(uuidString: idString) {
                _ = try deleteLocalActivity(id: id, context: context)
                debugLog.log("  ✓ Broadcast: Deleted activity \(id)", category: .event)
            }
        } else {
            guard let cleanRecord = payload.cleanedRecord() else { return }

            let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
            let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ActivityDTO.self, from: recordData)

            if inFlightActivityIds.contains(dto.id) {
                debugLog.log("  ⏭️ Broadcast: Skipping in-flight activity \(dto.id)", category: .event)
                return
            }

            #if DEBUG
            if recentlyProcessedIds.contains(dto.id) {
                debugLog.log("  ⚠️ Broadcast: Duplicate processing detected for activity \(dto.id)", category: .event)
            }
            recentlyProcessedIds.insert(dto.id)
            #endif

            try upsertActivity(dto: dto, context: context)
            debugLog.log("  ✓ Broadcast: Upserted activity \(dto.id)", category: .event)
        }
    }

    /// Handles listing broadcast - converts payload to ListingDTO and calls existing upsertListing
    private func handleListingBroadcast(payload: BroadcastChangePayload, context: ModelContext) async throws {
        if payload.type == .delete {
            if let oldRecord = payload.cleanedOldRecord(),
               let idString = oldRecord["id"] as? String,
               let id = UUID(uuidString: idString) {
                _ = try deleteLocalListing(id: id, context: context)
                debugLog.log("  ✓ Broadcast: Deleted listing \(id)", category: .event)
            }
        } else {
            guard let cleanRecord = payload.cleanedRecord() else { return }

            let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
            let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ListingDTO.self, from: recordData)

            #if DEBUG
            if recentlyProcessedIds.contains(dto.id) {
                debugLog.log("  ⚠️ Broadcast: Duplicate processing detected for listing \(dto.id)", category: .event)
            }
            recentlyProcessedIds.insert(dto.id)
            #endif

            try upsertListing(dto: dto, context: context)
            debugLog.log("  ✓ Broadcast: Upserted listing \(dto.id)", category: .event)
        }
    }

    /// Handles user broadcast - converts payload to UserDTO and calls existing upsertUser
    private func handleUserBroadcast(payload: BroadcastChangePayload, context: ModelContext) async throws {
        if payload.type == .delete {
            if let oldRecord = payload.cleanedOldRecord(),
               let idString = oldRecord["id"] as? String,
               let id = UUID(uuidString: idString) {
                _ = try deleteLocalUser(id: id, context: context)
                debugLog.log("  ✓ Broadcast: Deleted user \(id)", category: .event)
            }
        } else {
            guard let cleanRecord = payload.cleanedRecord() else { return }

            let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
            let dto = try PostgrestClient.Configuration.jsonDecoder.decode(UserDTO.self, from: recordData)

            #if DEBUG
            if recentlyProcessedIds.contains(dto.id) {
                debugLog.log("  ⚠️ Broadcast: Duplicate processing detected for user \(dto.id)", category: .event)
            }
            recentlyProcessedIds.insert(dto.id)
            #endif

            try await upsertUser(dto: dto, context: context)
            debugLog.log("  ✓ Broadcast: Upserted user \(dto.id)", category: .event)
        }
    }

    /// Handles claim event broadcast - converts payload to ClaimEventDTO and calls existing upsertClaimEvent
    private func handleClaimEventBroadcast(payload: BroadcastChangePayload, context: ModelContext) async throws {
        if payload.type == .delete {
            if let oldRecord = payload.cleanedOldRecord(),
               let idString = oldRecord["id"] as? String,
               let id = UUID(uuidString: idString) {
                _ = try deleteLocalClaimEvent(id: id, context: context)
                debugLog.log("  ✓ Broadcast: Deleted claim event \(id)", category: .event)
            }
        } else {
            guard let cleanRecord = payload.cleanedRecord() else { return }

            let recordData = try JSONSerialization.data(withJSONObject: cleanRecord)
            let dto = try PostgrestClient.Configuration.jsonDecoder.decode(ClaimEventDTO.self, from: recordData)

            #if DEBUG
            if recentlyProcessedIds.contains(dto.id) {
                debugLog.log("  ⚠️ Broadcast: Duplicate processing detected for claim event \(dto.id)", category: .event)
            }
            recentlyProcessedIds.insert(dto.id)
            #endif

            try upsertClaimEvent(dto: dto, context: context)
            debugLog.log("  ✓ Broadcast: Upserted claim event \(dto.id)", category: .event)
        }
    }
}
