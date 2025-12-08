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

    // MARK: - Published State
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncTime: Date?  // TODO Phase 2: Persist to UserDefaults
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
        debugLog.log("SyncManager singleton initialized", category: .sync)
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

    // MARK: - Sync Up (SwiftData → Supabase)
    private func syncUp(context: ModelContext) async throws {
        debugLog.log("syncUp() - pushing dirty entities to Supabase", category: .sync)
        debugLog.log("Sync order: Listings → Tasks → Activities (FK dependencies)", category: .sync)

        // Sync in FK dependency order: Listings first, then Tasks/Activities (which reference Listings)
        try await syncUpListings(context: context)
        try await syncUpTasks(context: context)
        try await syncUpActivities(context: context)
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
        let tables = ["tasks", "activities", "listings", "users"]
        debugLog.log("", category: .channel)
        debugLog.log("Configuring postgresChange() for \(tables.count) tables:", category: .channel)
        for table in tables {
            debugLog.logSubscriptionConfig(table: table, schema: "public", filter: nil)
        }

        debugLog.log("", category: .channel)
        debugLog.log("Creating AsyncSequence listeners...", category: .channel)
        let tasksChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "tasks")
        debugLog.log("  ✓ tasks listener created", category: .channel)
        let activitiesChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "activities")
        debugLog.log("  ✓ activities listener created", category: .channel)
        let listingsChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "listings")
        debugLog.log("  ✓ listings listener created", category: .channel)
        let usersChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "users")
        debugLog.log("  ✓ users listener created", category: .channel)

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
