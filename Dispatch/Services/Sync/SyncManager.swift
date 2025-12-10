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
import Combine

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

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
    @Published private(set) var syncStatus: SyncStatus = .synced
    @Published var currentUserID: UUID?  // Set when authenticated

    // MARK: - Private Properties
    private var modelContainer: ModelContainer?
    private var realtimeChannel: RealtimeChannelV2?
    private var isListening = false
    private var syncDebounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5  // 500ms

    private init() {
        // Restore persisted lastSyncTime
        self.lastSyncTime = UserDefaults.standard.object(forKey: Self.lastSyncTimeKey) as? Date
        debugLog.log("SyncManager singleton initialized", category: .sync)
        debugLog.log("  Restored lastSyncTime: \(lastSyncTime?.description ?? "nil")", category: .sync)
    }

    // MARK: - Configuration
    func configure(with container: ModelContainer, testUserID: UUID? = nil) {
        debugLog.log("configure() called", category: .sync)
        debugLog.log("  testUserID: \(testUserID?.uuidString ?? "nil")", category: .sync)
        self.modelContainer = container
        self.currentUserID = testUserID  // Stub for MVP
        debugLog.log("  modelContainer set: \(container)", category: .sync)
    }

    // MARK: - Auth Check
    private var isAuthenticated: Bool {
        currentUserID != nil
    }

    // MARK: - Main Sync (Debounced)
    func requestSync() {
        debugLog.log("requestSync() called - debouncing for \(debounceInterval)s", category: .sync)
        syncDebounceTask?.cancel()
        debugLog.log("  Previous debounce task cancelled (if any)", category: .sync)
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else {
                debugLog.log("  Debounce task was cancelled before sync", category: .sync)
                return
            }
            debugLog.log("  Debounce complete, triggering sync()", category: .sync)
            await sync()
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

    func sync() async {
        debugLog.log("========== sync() STARTED ==========", category: .sync)
        debugLog.log("  isAuthenticated: \(isAuthenticated)", category: .sync)
        debugLog.log("  isSyncing: \(isSyncing)", category: .sync)
        debugLog.log("  currentUserID: \(currentUserID?.uuidString ?? "nil")", category: .sync)
        debugLog.log("  lastSyncTime: \(lastSyncTime?.description ?? "nil")", category: .sync)

        guard isAuthenticated else {
            debugLog.log("SKIPPING sync - not authenticated", category: .sync)
            syncStatus = .pending
            return
        }
        guard !isSyncing, let container = modelContainer else {
            debugLog.log("SKIPPING sync - \(isSyncing ? "already syncing" : "no modelContainer")", category: .sync)
            return
        }

        isSyncing = true
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
            syncStatus = .synced
            debugLog.endTiming("Full Sync")
            debugLog.log("========== sync() COMPLETED at \(lastSyncTime!) ==========", category: .sync)
        } catch {
            debugLog.endTiming("Full Sync")
            debugLog.error("========== sync() FAILED ==========", error: error)
            syncError = error
            syncStatus = .error
        }

        isSyncing = false
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

    // MARK: - Sync Down: Users (read-only)
    private func syncDownUsers(context: ModelContext, since: String) async throws {
        debugLog.log("syncDownUsers() - querying Supabase...", category: .sync)
        let dtos: [UserDTO] = try await supabase
            .from("users")
            .select()
            .gt("updated_at", value: since)
            .execute()
            .value

        debugLog.logSyncOperation(operation: "FETCH", table: "users", count: dtos.count)

        for (index, dto) in dtos.enumerated() {
            debugLog.log("  Upserting user \(index + 1)/\(dtos.count): \(dto.id) - \(dto.name)", category: .sync)
            try upsertUser(dto: dto, context: context)
        }
    }

    private func upsertUser(dto: UserDTO, context: ModelContext) throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == targetId }
        )

        if let existing = try context.fetch(descriptor).first {
            debugLog.log("    UPDATE existing user: \(dto.id)", category: .sync)
            existing.name = dto.name
            existing.email = dto.email
            existing.userType = UserType(rawValue: dto.userType) ?? .realtor
            existing.updatedAt = dto.updatedAt
            existing.syncedAt = Date()
        } else {
            debugLog.log("    INSERT new user: \(dto.id)", category: .sync)
            let newUser = dto.toModel()
            newUser.syncedAt = Date()
            context.insert(newUser)
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
            existing.assignedStaff = dto.assignedStaff
            existing.activatedAt = dto.activatedAt
            existing.pendingAt = dto.pendingAt
            existing.closedAt = dto.closedAt
            existing.deletedAt = dto.deletedAt
            existing.updatedAt = dto.updatedAt
            existing.syncedAt = Date()
        } else {
            debugLog.log("    INSERT new listing: \(dto.id)", category: .sync)
            let newListing = dto.toModel()
            newListing.syncedAt = Date()
            context.insert(newListing)
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

        let task: TaskItem
        if let existing = try context.fetch(descriptor).first {
            debugLog.log("    UPDATE existing task: \(dto.id)", category: .sync)
            // Update (last-write-wins: server wins on syncDown)
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
            existing.listingId = dto.listing  // Ensure listingId is updated
            existing.syncedAt = Date()
            task = existing
        } else {
            debugLog.log("    INSERT new task: \(dto.id)", category: .sync)
            let newTask = dto.toModel()
            newTask.syncedAt = Date()
            context.insert(newTask)
            task = newTask
        }

        // Establish SwiftData relationship with parent Listing
        try establishTaskListingRelationship(task: task, listingId: dto.listing, context: context)
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

        let activity: Activity
        if let existing = try context.fetch(descriptor).first {
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
            existing.listingId = dto.listing  // Ensure listingId is updated
            existing.syncedAt = Date()
            activity = existing
        } else {
            debugLog.log("    INSERT new activity: \(dto.id)", category: .sync)
            let newActivity = dto.toModel()
            newActivity.syncedAt = Date()
            context.insert(newActivity)
            activity = newActivity
        }

        // Establish SwiftData relationship with parent Listing
        try establishActivityListingRelationship(activity: activity, listingId: dto.listing, context: context)
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
            existing.syncedAt = Date()
        } else {
            debugLog.log("    INSERT new claim event: \(dto.id)", category: .sync)
            let newClaimEvent = dto.toModel()
            newClaimEvent.syncedAt = Date()
            context.insert(newClaimEvent)
        }
    }

    // MARK: - Sync Up (SwiftData → Supabase)
    private func syncUp(context: ModelContext) async throws {
        debugLog.log("syncUp() - pushing dirty entities to Supabase", category: .sync)
        debugLog.log("Sync order: Listings → Tasks → Activities → ClaimEvents (FK dependencies)", category: .sync)

        // Sync in FK dependency order: Listings first, then Tasks/Activities (which reference Listings)
        try await syncUpListings(context: context)
        try await syncUpTasks(context: context)
        try await syncUpActivities(context: context)
        try await syncUpClaimEvents(context: context)
        // NOTE: No syncUpUsers() - Users are READ-ONLY (RLS policy prevents non-self updates)
        // Profile edits will be handled in a separate authenticated flow
        debugLog.log("syncUp() complete", category: .sync)
    }

    private func syncUpTasks(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<TaskItem>()
        let allTasks = try context.fetch(descriptor)
        debugLog.log("syncUpTasks() - fetched \(allTasks.count) total tasks from SwiftData", category: .sync)

        // NOTE: Fetching all then filtering is O(n) memory. For 1000+ tasks this could be slow.
        // Phase 2 optimization: add persisted `needsSync: Bool` flag for predicate-based fetch.
        let dirtyTasks = allTasks.filter { $0.isDirty }
        debugLog.logSyncOperation(operation: "DIRTY", table: "tasks", count: dirtyTasks.count, details: "of \(allTasks.count) total")

        guard !dirtyTasks.isEmpty else {
            debugLog.log("  No dirty tasks to sync", category: .sync)
            return
        }

        // Batch upsert for efficiency (fewer network calls)
        let dtos = dirtyTasks.map { TaskDTO(from: $0) }
        debugLog.log("  Upserting \(dtos.count) tasks to Supabase...", category: .sync)
        try await supabase
            .from("tasks")
            .upsert(dtos)
            .execute()
        debugLog.log("  Upsert successful", category: .sync)

        // Mark all as synced
        let now = Date()
        for task in dirtyTasks {
            task.syncedAt = now
        }
        debugLog.log("  Marked \(dirtyTasks.count) tasks as synced", category: .sync)
    }

    private func syncUpActivities(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Activity>()
        let allActivities = try context.fetch(descriptor)
        debugLog.log("syncUpActivities() - fetched \(allActivities.count) total activities from SwiftData", category: .sync)

        let dirtyActivities = allActivities.filter { $0.isDirty }
        debugLog.logSyncOperation(operation: "DIRTY", table: "activities", count: dirtyActivities.count, details: "of \(allActivities.count) total")

        guard !dirtyActivities.isEmpty else {
            debugLog.log("  No dirty activities to sync", category: .sync)
            return
        }

        let dtos = dirtyActivities.map { ActivityDTO(from: $0) }
        debugLog.log("  Upserting \(dtos.count) activities to Supabase...", category: .sync)
        try await supabase
            .from("activities")
            .upsert(dtos)
            .execute()
        debugLog.log("  Upsert successful", category: .sync)

        let now = Date()
        for activity in dirtyActivities {
            activity.syncedAt = now
        }
        debugLog.log("  Marked \(dirtyActivities.count) activities as synced", category: .sync)
    }

    private func syncUpListings(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Listing>()
        let allListings = try context.fetch(descriptor)
        debugLog.log("syncUpListings() - fetched \(allListings.count) total listings from SwiftData", category: .sync)

        let dirtyListings = allListings.filter { $0.isDirty }
        debugLog.logSyncOperation(operation: "DIRTY", table: "listings", count: dirtyListings.count, details: "of \(allListings.count) total")

        guard !dirtyListings.isEmpty else {
            debugLog.log("  No dirty listings to sync", category: .sync)
            return
        }

        let dtos = dirtyListings.map { ListingDTO(from: $0) }
        debugLog.log("  Upserting \(dtos.count) listings to Supabase...", category: .sync)
        try await supabase
            .from("listings")
            .upsert(dtos)
            .execute()
        debugLog.log("  Upsert successful", category: .sync)

        let now = Date()
        for listing in dirtyListings {
            listing.syncedAt = now
        }
        debugLog.log("  Marked \(dirtyListings.count) listings as synced", category: .sync)
    }

    private func syncUpClaimEvents(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<ClaimEvent>()
        let allClaimEvents = try context.fetch(descriptor)
        debugLog.log("syncUpClaimEvents() - fetched \(allClaimEvents.count) total claim events from SwiftData", category: .sync)

        let dirtyClaimEvents = allClaimEvents.filter { $0.isDirty }
        debugLog.logSyncOperation(operation: "DIRTY", table: "claim_events", count: dirtyClaimEvents.count, details: "of \(allClaimEvents.count) total")

        guard !dirtyClaimEvents.isEmpty else {
            debugLog.log("  No dirty claim events to sync", category: .sync)
            return
        }

        let dtos = dirtyClaimEvents.map { ClaimEventDTO(from: $0) }
        debugLog.log("  Upserting \(dtos.count) claim events to Supabase...", category: .sync)
        try await supabase
            .from("claim_events")
            .upsert(dtos)
            .execute()
        debugLog.log("  Upsert successful", category: .sync)

        let now = Date()
        for claimEvent in dirtyClaimEvents {
            claimEvent.syncedAt = now
        }
        debugLog.log("  Marked \(dirtyClaimEvents.count) claim events as synced", category: .sync)
    }

    // MARK: - Realtime (Debounced Full Sync)
    private var realtimeListenerTasks: [Task<Void, Never>] = []

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

        // Start socket status monitoring
        debugLog.log("", category: .websocket)
        debugLog.log("Setting up WebSocket status monitor...", category: .websocket)
        let socketStatusTask = Task { @MainActor in
            debugLog.log("📡 Socket status monitor task STARTED", category: .websocket)
            for await status in supabase.realtimeV2.statusChange {
                switch status {
                case .disconnected:
                    debugLog.log("🔴 SOCKET DISCONNECTED", category: .websocket)
                    debugLog.log("  ⚠️ This means realtime events WILL NOT be received!", category: .websocket)
                case .connecting:
                    debugLog.log("🟡 SOCKET CONNECTING...", category: .websocket)
                case .connected:
                    debugLog.log("🟢 SOCKET CONNECTED", category: .websocket)
                    debugLog.log("  ✓ WebSocket connection established", category: .websocket)
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
        debugLog.log("Creating AsyncSequence listeners...", category: .channel)

        // AnyAction listeners for INSERT/UPDATE events (trigger sync)
        let tasksChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "tasks")
        debugLog.log("  ✓ tasks listener created", category: .channel)
        let activitiesChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "activities")
        debugLog.log("  ✓ activities listener created", category: .channel)
        let listingsChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "listings")
        debugLog.log("  ✓ listings listener created", category: .channel)
        let usersChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "users")
        debugLog.log("  ✓ users listener created", category: .channel)
        let claimEventsChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "claim_events")
        debugLog.log("  ✓ claim_events listener created", category: .channel)

        // DELETE-specific listeners for immediate local deletion
        // Note: These handle hard deletes from Supabase immediately without waiting for sync
        let tasksDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "tasks")
        debugLog.log("  ✓ tasks DELETE listener created", category: .channel)
        let activitiesDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "activities")
        debugLog.log("  ✓ activities DELETE listener created", category: .channel)
        let listingsDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "listings")
        debugLog.log("  ✓ listings DELETE listener created", category: .channel)
        let usersDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "users")
        debugLog.log("  ✓ users DELETE listener created", category: .channel)

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
            socketStatusTask.cancel()
            isListening = false
            return
        }

        // Monitor channel status
        let channelStatusTask = Task { @MainActor in
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

        // Create listener tasks with verbose logging
        debugLog.log("", category: .event)
        debugLog.log("Creating for-await listener tasks for each table...", category: .event)

        realtimeListenerTasks = [
            socketStatusTask,
            channelStatusTask,
            Task { @MainActor in
                debugLog.logForAwaitLoop(entering: true, table: "tasks")
                var eventCount = 0
                for await change in tasksChanges {
                    eventCount += 1
                    debugLog.log("", category: .event)
                    debugLog.log("🎉🎉🎉 TASKS EVENT #\(eventCount) RECEIVED! 🎉🎉🎉", category: .event)
                    debugLog.logEventReceived(table: "tasks", action: "\(type(of: change))", payload: nil)
                    requestSync()
                }
                debugLog.logForAwaitLoop(entering: false, table: "tasks")
                debugLog.log("⚠️ tasks for-await loop EXITED after \(eventCount) events", category: .event)
            },
            Task { @MainActor in
                debugLog.logForAwaitLoop(entering: true, table: "activities")
                var eventCount = 0
                for await change in activitiesChanges {
                    eventCount += 1
                    debugLog.log("", category: .event)
                    debugLog.log("🎉🎉🎉 ACTIVITIES EVENT #\(eventCount) RECEIVED! 🎉🎉🎉", category: .event)
                    debugLog.logEventReceived(table: "activities", action: "\(type(of: change))", payload: nil)
                    requestSync()
                }
                debugLog.logForAwaitLoop(entering: false, table: "activities")
                debugLog.log("⚠️ activities for-await loop EXITED after \(eventCount) events", category: .event)
            },
            Task { @MainActor in
                debugLog.logForAwaitLoop(entering: true, table: "listings")
                var eventCount = 0
                for await change in listingsChanges {
                    eventCount += 1
                    debugLog.log("", category: .event)
                    debugLog.log("🎉🎉🎉 LISTINGS EVENT #\(eventCount) RECEIVED! 🎉🎉🎉", category: .event)
                    debugLog.logEventReceived(table: "listings", action: "\(type(of: change))", payload: nil)
                    requestSync()
                }
                debugLog.logForAwaitLoop(entering: false, table: "listings")
                debugLog.log("⚠️ listings for-await loop EXITED after \(eventCount) events", category: .event)
            },
            Task { @MainActor in
                debugLog.logForAwaitLoop(entering: true, table: "users")
                var eventCount = 0
                for await change in usersChanges {
                    eventCount += 1
                    debugLog.log("", category: .event)
                    debugLog.log("🎉🎉🎉 USERS EVENT #\(eventCount) RECEIVED! 🎉🎉🎉", category: .event)
                    debugLog.logEventReceived(table: "users", action: "\(type(of: change))", payload: nil)
                    requestSync()
                }
                debugLog.logForAwaitLoop(entering: false, table: "users")
                debugLog.log("⚠️ users for-await loop EXITED after \(eventCount) events", category: .event)
            },
            Task { @MainActor in
                debugLog.logForAwaitLoop(entering: true, table: "claim_events")
                var eventCount = 0
                for await change in claimEventsChanges {
                    eventCount += 1
                    debugLog.log("", category: .event)
                    debugLog.log("🎉🎉🎉 CLAIM_EVENTS EVENT #\(eventCount) RECEIVED! 🎉🎉🎉", category: .event)
                    debugLog.logEventReceived(table: "claim_events", action: "\(type(of: change))", payload: nil)
                    requestSync()
                }
                debugLog.logForAwaitLoop(entering: false, table: "claim_events")
                debugLog.log("⚠️ claim_events for-await loop EXITED after \(eventCount) events", category: .event)
            },
            // DELETE-specific handlers for immediate local deletion
            // Note: These provide immediate deletion when realtime DELETE events are received.
            // The orphan reconciliation in syncDown() serves as a fallback safety net.
            Task { @MainActor [weak self] in
                guard let self = self, let container = self.modelContainer else { return }
                debugLog.log("🗑️ Tasks DELETE listener STARTED", category: .event)
                for await deleteEvent in tasksDeletes {
                    debugLog.log("", category: .event)
                    debugLog.log("🗑️🗑️🗑️ TASKS DELETE EVENT RECEIVED! 🗑️🗑️🗑️", category: .event)
                    // Extract deleted ID from oldRecord using JSON description and parse
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
            },
            Task { @MainActor [weak self] in
                guard let self = self, let container = self.modelContainer else { return }
                debugLog.log("🗑️ Activities DELETE listener STARTED", category: .event)
                for await deleteEvent in activitiesDeletes {
                    debugLog.log("", category: .event)
                    debugLog.log("🗑️🗑️🗑️ ACTIVITIES DELETE EVENT RECEIVED! 🗑️🗑️🗑️", category: .event)
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
            },
            Task { @MainActor [weak self] in
                guard let self = self, let container = self.modelContainer else { return }
                debugLog.log("🗑️ Listings DELETE listener STARTED", category: .event)
                for await deleteEvent in listingsDeletes {
                    debugLog.log("", category: .event)
                    debugLog.log("🗑️🗑️🗑️ LISTINGS DELETE EVENT RECEIVED! 🗑️🗑️🗑️", category: .event)
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
            },
            Task { @MainActor [weak self] in
                guard let self = self, let container = self.modelContainer else { return }
                debugLog.log("🗑️ Users DELETE listener STARTED", category: .event)
                for await deleteEvent in usersDeletes {
                    debugLog.log("", category: .event)
                    debugLog.log("🗑️🗑️🗑️ USERS DELETE EVENT RECEIVED! 🗑️🗑️🗑️", category: .event)
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
        ]

        realtimeChannel = channel

        debugLog.log("", category: .realtime)
        debugLog.log("╔════════════════════════════════════════════════════════════╗", category: .realtime)
        debugLog.log("║           REALTIME SETUP COMPLETE                          ║", category: .realtime)
        debugLog.log("╚════════════════════════════════════════════════════════════╝", category: .realtime)
        debugLog.log("  Listener tasks created: \(realtimeListenerTasks.count)", category: .realtime)
        debugLog.log("  Tables monitored: \(tables.joined(separator: ", "))", category: .realtime)
        debugLog.log("", category: .realtime)
        debugLog.log("Waiting for database changes...", category: .realtime)
        debugLog.log("  To test: UPDATE a row in Supabase dashboard", category: .realtime)
        debugLog.log("  Expected: '[EVENT] 🎉🎉🎉 EVENT RECEIVED!' message", category: .realtime)
    }

    func stopListening() async {
        debugLog.log("stopListening() called", category: .realtime)
        debugLog.log("  Cancelling \(realtimeListenerTasks.count) listener tasks...", category: .realtime)

        // Cancel all listener tasks
        for (index, task) in realtimeListenerTasks.enumerated() {
            debugLog.log("  Cancelling task \(index + 1)...", category: .realtime)
            task.cancel()
        }
        realtimeListenerTasks.removeAll()
        debugLog.log("  All tasks cancelled and removed", category: .realtime)

        if let channel = realtimeChannel {
            debugLog.log("  Unsubscribing from channel...", category: .realtime)
            await channel.unsubscribe()
            debugLog.log("  Channel unsubscribed", category: .realtime)
        }
        realtimeChannel = nil
        isListening = false
        debugLog.log("✓ Realtime stopped. isListening = false", category: .realtime)
    }
}
