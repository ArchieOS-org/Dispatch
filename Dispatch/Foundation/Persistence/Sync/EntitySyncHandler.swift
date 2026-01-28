//
//  EntitySyncHandler.swift
//  Dispatch
//
//  Coordinator for all entity sync operations.
//  Delegates entity-specific logic to dedicated handlers while managing
//  cross-entity relationships and reconciliation.
//

import Foundation
import PostgREST
import Supabase
import SwiftData

// MARK: - EntitySyncHandler

/// Coordinator for all entity sync operations.
/// Delegates to entity-specific handlers and manages cross-entity relationships.
@MainActor
final class EntitySyncHandler {

  // MARK: Lifecycle

  init(
    mode: SyncRunMode,
    conflictResolver: ConflictResolver,
    getCurrentUserID: @escaping () -> UUID?,
    getCurrentUser: @escaping () -> User?,
    fetchCurrentUser: @escaping (UUID) -> Void,
    updateListingConfigReady: @escaping (Bool) -> Void
  ) {
    self.mode = mode
    self.conflictResolver = conflictResolver
    self.getCurrentUserID = getCurrentUserID
    self.getCurrentUser = getCurrentUser
    self.fetchCurrentUser = fetchCurrentUser
    self.updateListingConfigReady = updateListingConfigReady

    // Create shared dependencies for entity handlers
    let dependencies = SyncHandlerDependencies(
      mode: mode,
      conflictResolver: conflictResolver,
      getCurrentUserID: getCurrentUserID,
      getCurrentUser: getCurrentUser,
      fetchCurrentUser: fetchCurrentUser,
      updateListingConfigReady: updateListingConfigReady
    )

    // Initialize entity-specific handlers
    userSyncHandler = UserSyncHandler(dependencies: dependencies)
    propertySyncHandler = PropertySyncHandler(dependencies: dependencies)
    listingSyncHandler = ListingSyncHandler(dependencies: dependencies)
    taskSyncHandler = TaskSyncHandler(dependencies: dependencies)
    activitySyncHandler = ActivitySyncHandler(dependencies: dependencies)
    noteSyncHandler = NoteSyncHandler(dependencies: dependencies)
  }

  // MARK: Internal

  nonisolated let mode: SyncRunMode

  // MARK: - Dependencies

  let conflictResolver: ConflictResolver
  let getCurrentUserID: () -> UUID?
  let getCurrentUser: () -> User?
  let fetchCurrentUser: (UUID) -> Void
  let updateListingConfigReady: (Bool) -> Void

  // MARK: - Entity Handlers

  let userSyncHandler: UserSyncHandler
  let propertySyncHandler: PropertySyncHandler
  let listingSyncHandler: ListingSyncHandler
  let taskSyncHandler: TaskSyncHandler
  let activitySyncHandler: ActivitySyncHandler
  let noteSyncHandler: NoteSyncHandler

  // MARK: - SyncDown Operations

  func syncDownUsers(context: ModelContext, since: String) async throws {
    try await userSyncHandler.syncDown(context: context, since: since)
  }

  func syncDownProperties(context: ModelContext, since: String) async throws {
    try await propertySyncHandler.syncDown(context: context, since: since)
  }

  func syncDownListings(context: ModelContext, since: String) async throws {
    try await listingSyncHandler.syncDownListings(context: context, since: since) { listing, ownerId, ctx in
      try self.establishListingOwnerRelationship(listing: listing, ownerId: ownerId, context: ctx)
    }
  }

  func syncDownTasks(context: ModelContext, since: String) async throws {
    try await taskSyncHandler.syncDownTasks(context: context, since: since) { task, listingId, ctx in
      try self.establishTaskListingRelationship(task: task, listingId: listingId, context: ctx)
    }
  }

  func syncDownActivities(context: ModelContext, since: String) async throws {
    try await activitySyncHandler.syncDownActivities(context: context, since: since) { activity, listingId, ctx in
      try self.establishActivityListingRelationship(activity: activity, listingId: listingId, context: ctx)
    }
  }

  func syncDownTaskAssignees(context: ModelContext, since: String) async throws {
    try await taskSyncHandler.syncDownTaskAssignees(context: context, since: since) { assignee, taskId, ctx in
      try self.establishTaskAssigneeRelationship(assignee: assignee, taskId: taskId, context: ctx)
    }
  }

  func syncDownActivityAssignees(context: ModelContext, since: String) async throws {
    try await activitySyncHandler.syncDownActivityAssignees(context: context, since: since) { assignee, activityId, ctx in
      try self.establishActivityAssigneeRelationship(assignee: assignee, activityId: activityId, context: ctx)
    }
  }

  func syncDownListingTypes(context: ModelContext) async throws {
    try await listingSyncHandler.syncDownListingTypes(context: context)
  }

  func syncDownActivityTemplates(context: ModelContext) async throws {
    try await activitySyncHandler.syncDownActivityTemplates(context: context)
  }

  func syncDownNotes(context: ModelContext) async throws {
    try await noteSyncHandler.syncDown(context: context, since: "")
  }

  func reconcileMissingNotes(context: ModelContext) async throws -> Int {
    try await noteSyncHandler.reconcileMissingNotes(context: context)
  }

  func reconcileMissingListings(context: ModelContext) async throws -> Int {
    try await listingSyncHandler.reconcileMissingListings(context: context)
  }

  func reconcileMissingTasks(context: ModelContext) async throws -> Int {
    try await taskSyncHandler.reconcileMissingTasks(context: context)
  }

  func reconcileMissingActivities(context: ModelContext) async throws -> Int {
    try await activitySyncHandler.reconcileMissingActivities(context: context)
  }

  // MARK: - SyncUp Operations

  func syncUpUsers(context: ModelContext) async throws {
    try await userSyncHandler.syncUp(context: context)
  }

  func syncUpProperties(context: ModelContext) async throws {
    try await propertySyncHandler.syncUp(context: context)
  }

  func syncUpListings(context: ModelContext) async throws {
    try await listingSyncHandler.syncUp(context: context)
  }

  func syncUpTasks(context: ModelContext) async throws {
    try await taskSyncHandler.syncUp(context: context)
  }

  func syncUpActivities(context: ModelContext) async throws {
    try await activitySyncHandler.syncUp(context: context)
  }

  func syncUpTaskAssignees(context: ModelContext, taskIdsToSync: Set<UUID>? = nil) async throws {
    try await taskSyncHandler.syncUpTaskAssignees(context: context, taskIdsToSync: taskIdsToSync)
  }

  func syncUpActivityAssignees(context: ModelContext, activityIdsToSync: Set<UUID>? = nil) async throws {
    try await activitySyncHandler.syncUpActivityAssignees(context: context, activityIdsToSync: activityIdsToSync)
  }

  func syncUpListingTypes(context: ModelContext) async throws {
    try await listingSyncHandler.syncUpListingTypes(context: context)
  }

  func syncUpActivityTemplates(context: ModelContext) async throws {
    try await activitySyncHandler.syncUpActivityTemplates(context: context)
  }

  func syncUpNotes(context: ModelContext) async throws {
    try await noteSyncHandler.syncUp(context: context)
  }

  // MARK: - Upsert Methods (Coordinator provides relationship callbacks)

  func upsertUser(dto: UserDTO, context: ModelContext) async throws {
    try await userSyncHandler.upsertUser(dto: dto, context: context)
  }

  func upsertProperty(dto: PropertyDTO, context: ModelContext) throws {
    try propertySyncHandler.upsertProperty(dto: dto, context: context)
  }

  func upsertListing(dto: ListingDTO, context: ModelContext) throws {
    try listingSyncHandler.upsertListing(dto: dto, context: context) { listing, ownerId, ctx in
      try self.establishListingOwnerRelationship(listing: listing, ownerId: ownerId, context: ctx)
    }
  }

  func upsertTask(dto: TaskDTO, context: ModelContext) throws {
    try taskSyncHandler.upsertTask(dto: dto, context: context) { task, listingId, ctx in
      try self.establishTaskListingRelationship(task: task, listingId: listingId, context: ctx)
    }
  }

  func upsertActivity(dto: ActivityDTO, context: ModelContext) throws {
    try activitySyncHandler.upsertActivity(dto: dto, context: context) { activity, listingId, ctx in
      try self.establishActivityListingRelationship(activity: activity, listingId: listingId, context: ctx)
    }
  }

  func upsertTaskAssignee(dto: TaskAssigneeDTO, context: ModelContext) throws {
    try taskSyncHandler.upsertTaskAssignee(dto: dto, context: context) { assignee, taskId, ctx in
      try self.establishTaskAssigneeRelationship(assignee: assignee, taskId: taskId, context: ctx)
    }
  }

  func upsertActivityAssignee(dto: ActivityAssigneeDTO, context: ModelContext) throws {
    try activitySyncHandler.upsertActivityAssignee(dto: dto, context: context) { assignee, activityId, ctx in
      try self.establishActivityAssigneeRelationship(assignee: assignee, activityId: activityId, context: ctx)
    }
  }

  func upsertActivityTemplate(
    dto: ActivityTemplateDTO,
    context: ModelContext,
    localTypes: [ListingTypeDefinition]
  ) throws {
    try activitySyncHandler.upsertActivityTemplate(dto: dto, context: context, localTypes: localTypes)
  }

  func applyRemoteNote(dto: NoteDTO, source: NoteSyncHandler.RemoteNoteSource, context: ModelContext) throws {
    try noteSyncHandler.applyRemoteNote(dto: dto, source: source, context: context)
  }

  // MARK: - Delete Methods

  func deleteLocalTask(id: UUID, context: ModelContext) throws -> Bool {
    try taskSyncHandler.deleteLocalTask(id: id, context: context)
  }

  func deleteLocalActivity(id: UUID, context: ModelContext) throws -> Bool {
    try activitySyncHandler.deleteLocalActivity(id: id, context: context)
  }

  func deleteLocalListing(id: UUID, context: ModelContext) throws -> Bool {
    try listingSyncHandler.deleteLocalListing(id: id, context: context)
  }

  func deleteLocalUser(id: UUID, context: ModelContext) throws -> Bool {
    try userSyncHandler.deleteLocalUser(id: id, context: context)
  }

  func deleteLocalNote(id: UUID, context: ModelContext) throws -> Bool {
    try noteSyncHandler.deleteLocalNote(id: id, context: context)
  }

  // MARK: - Relationship Establishment

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
    }
    // If user not found, that's expected in initial sync - relationship deferred
  }

  func establishTaskListingRelationship(task: TaskItem, listingId: UUID?, context: ModelContext) throws {
    // Remove from old listing if listingId changed
    if let oldListing = task.listing, oldListing.id != listingId {
      debugLog.log("      Removing task from old listing: \(oldListing.id)", category: .sync)
      oldListing.tasks.removeAll { $0.id == task.id }
      task.listing = nil
    }

    // Add to new listing if listingId is set
    guard let listingId else {
      debugLog.log("      No listingId - task is standalone", category: .sync)
      return
    }

    let listingDescriptor = FetchDescriptor<Listing>(
      predicate: #Predicate { $0.id == listingId }
    )

    guard let parentListing = try context.fetch(listingDescriptor).first else {
      debugLog.log("      Warning: Parent listing \(listingId) not found - relationship deferred", category: .sync)
      return
    }

    // Establish bidirectional relationship
    if !parentListing.tasks.contains(where: { $0.id == task.id }) {
      debugLog.log("      Adding task to listing.tasks: \(listingId)", category: .sync)
      parentListing.tasks.append(task)
    }
    task.listing = parentListing
  }

  func establishActivityListingRelationship(activity: Activity, listingId: UUID?, context: ModelContext) throws {
    // Remove from old listing if listingId changed
    if let oldListing = activity.listing, oldListing.id != listingId {
      debugLog.log("      Removing activity from old listing: \(oldListing.id)", category: .sync)
      oldListing.activities.removeAll { $0.id == activity.id }
      activity.listing = nil
    }

    // Add to new listing if listingId is set
    guard let listingId else {
      debugLog.log("      No listingId - activity is standalone", category: .sync)
      return
    }

    let listingDescriptor = FetchDescriptor<Listing>(
      predicate: #Predicate { $0.id == listingId }
    )

    guard let parentListing = try context.fetch(listingDescriptor).first else {
      debugLog.log("      Warning: Parent listing \(listingId) not found - relationship deferred", category: .sync)
      return
    }

    // Establish bidirectional relationship
    if !parentListing.activities.contains(where: { $0.id == activity.id }) {
      debugLog.log("      Adding activity to listing.activities: \(listingId)", category: .sync)
      parentListing.activities.append(activity)
    }
    activity.listing = parentListing
  }

  func establishTaskAssigneeRelationship(assignee: TaskAssignee, taskId: UUID, context: ModelContext) throws {
    let taskDescriptor = FetchDescriptor<TaskItem>(
      predicate: #Predicate { $0.id == taskId }
    )

    guard let parentTask = try context.fetch(taskDescriptor).first else {
      debugLog.log("      Warning: Parent task \(taskId) not found - relationship deferred", category: .sync)
      return
    }

    debugLog.log(
      "      RELATIONSHIP task=\(parentTask.id) assignee=\(assignee.id) taskState=\(parentTask.syncState)",
      category: .sync
    )

    if !parentTask.assignees.contains(where: { $0.id == assignee.id }) {
      parentTask.assignees.append(assignee)
    }
    assignee.task = parentTask
  }

  func establishActivityAssigneeRelationship(assignee: ActivityAssignee, activityId: UUID, context: ModelContext) throws {
    let activityDescriptor = FetchDescriptor<Activity>(
      predicate: #Predicate { $0.id == activityId }
    )

    guard let parentActivity = try context.fetch(activityDescriptor).first else {
      debugLog.log("      Warning: Parent activity \(activityId) not found - relationship deferred", category: .sync)
      return
    }

    if !parentActivity.assignees.contains(where: { $0.id == assignee.id }) {
      parentActivity.assignees.append(assignee)
    }
    assignee.activity = parentActivity
  }

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

  func reconcileListingPropertyRelationships(context: ModelContext) throws {
    let listingsDescriptor = FetchDescriptor<Listing>()
    let propertiesDescriptor = FetchDescriptor<Property>()

    let allListings = try context.fetch(listingsDescriptor)
    let allProperties = try context.fetch(propertiesDescriptor)

    // Build property lookup by ID
    let propertiesById = Dictionary(uniqueKeysWithValues: allProperties.map { ($0.id, $0) })

    var linkedCount = 0
    for listing in allListings {
      if let propertyId = listing.propertyId, listing.property == nil {
        if let property = propertiesById[propertyId] {
          listing.property = property
          linkedCount += 1
        }
      }
    }

    if linkedCount > 0 {
      debugLog.log("  Linked \(linkedCount) listings to their properties", category: .sync)
    }
  }

  // MARK: - Orphan Reconciliation

  func reconcileOrphans(context: ModelContext) async throws {
    debugLog.log("", category: .sync)
    debugLog.log("============================================================", category: .sync)
    debugLog.log("           ORPHAN RECONCILIATION                            ", category: .sync)
    debugLog.log("============================================================", category: .sync)

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

    // Reconcile TaskAssignees
    debugLog.log("Reconciling TaskAssignees...", category: .sync)
    let taskAssigneesDeleted = try await reconcileOrphanTaskAssignees(context: context)
    totalDeleted += taskAssigneesDeleted

    // Reconcile ActivityAssignees
    debugLog.log("Reconciling ActivityAssignees...", category: .sync)
    let activityAssigneesDeleted = try await reconcileOrphanActivityAssignees(context: context)
    totalDeleted += activityAssigneesDeleted

    debugLog.log("", category: .sync)
    debugLog.log("Orphan reconciliation complete: deleted \(totalDeleted) total orphan records", category: .sync)
  }

  func reconcileOrphanTasks(context: ModelContext) async throws -> Int {
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
        debugLog.log("  Deleting orphan task: \(task.id) - \(task.title)", category: .sync)
        context.delete(task)
        deletedCount += 1
      }
    }

    debugLog.log("  Deleted \(deletedCount) orphan tasks", category: .sync)
    return deletedCount
  }

  func reconcileOrphanActivities(context: ModelContext) async throws -> Int {
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
        debugLog.log("  Deleting orphan activity: \(activity.id) - \(activity.title)", category: .sync)
        context.delete(activity)
        deletedCount += 1
      }
    }

    debugLog.log("  Deleted \(deletedCount) orphan activities", category: .sync)
    return deletedCount
  }

  func reconcileOrphanListings(context: ModelContext) async throws -> Int {
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
        debugLog.log("  Deleting orphan listing: \(listing.id) - \(listing.address)", category: .sync)
        context.delete(listing)
        deletedCount += 1
      }
    }

    debugLog.log("  Deleted \(deletedCount) orphan listings", category: .sync)
    return deletedCount
  }

  func reconcileOrphanUsers(context: ModelContext) async throws -> Int {
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
        debugLog.log("  Deleting orphan user: \(user.id) - \(user.name)", category: .sync)
        context.delete(user)
        deletedCount += 1
      }
    }

    debugLog.log("  Deleted \(deletedCount) orphan users", category: .sync)
    return deletedCount
  }

  func reconcileOrphanTaskAssignees(context: ModelContext) async throws -> Int {
    let remoteDTOs: [IDOnlyDTO] = try await supabase
      .from("task_assignees")
      .select("id")
      .execute()
      .value
    let remoteIds = Set(remoteDTOs.map { $0.id })
    debugLog.log("  Remote task assignees: \(remoteIds.count)", category: .sync)

    let localDescriptor = FetchDescriptor<TaskAssignee>()
    let localAssignees = try context.fetch(localDescriptor)
    debugLog.log("  Local task assignees: \(localAssignees.count)", category: .sync)

    var deletedCount = 0
    for assignee in localAssignees {
      if !remoteIds.contains(assignee.id) {
        debugLog.log("  Deleting orphan task assignee: \(assignee.id)", category: .sync)
        context.delete(assignee)
        deletedCount += 1
      }
    }

    debugLog.log("  Deleted \(deletedCount) orphan task assignees", category: .sync)
    return deletedCount
  }

  func reconcileOrphanActivityAssignees(context: ModelContext) async throws -> Int {
    let remoteDTOs: [IDOnlyDTO] = try await supabase
      .from("activity_assignees")
      .select("id")
      .execute()
      .value
    let remoteIds = Set(remoteDTOs.map { $0.id })
    debugLog.log("  Remote activity assignees: \(remoteIds.count)", category: .sync)

    let localDescriptor = FetchDescriptor<ActivityAssignee>()
    let localAssignees = try context.fetch(localDescriptor)
    debugLog.log("  Local activity assignees: \(localAssignees.count)", category: .sync)

    var deletedCount = 0
    for assignee in localAssignees {
      if !remoteIds.contains(assignee.id) {
        debugLog.log("  Deleting orphan activity assignee: \(assignee.id)", category: .sync)
        context.delete(assignee)
        deletedCount += 1
      }
    }

    debugLog.log("  Deleted \(deletedCount) orphan activity assignees", category: .sync)
    return deletedCount
  }

  /// One-time local migration to catch "phantom" users that are marked .synced but were never uploaded (syncedAt == nil)
  /// OR users who have avatar data but no hash (legacy data).
  func reconcileLegacyLocalUsers(context: ModelContext) async throws {
    try await userSyncHandler.reconcileLegacyLocalUsers(context: context)
  }

  // MARK: Private

  // MARK: - Private Helpers

  /// Lightweight DTO for fetching only IDs from Supabase
  private struct IDOnlyDTO: Codable {
    let id: UUID
  }
}
