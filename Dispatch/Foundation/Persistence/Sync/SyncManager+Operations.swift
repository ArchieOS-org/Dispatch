//
//  SyncManager+Operations.swift
//  Dispatch
//
//  Extracted from SyncManager.swift for cohesion.
//  Contains sync direction operations: syncDown and syncUp.
//

import Foundation
import SwiftData

// MARK: - SyncManager + Sync Operations

extension SyncManager {

  // MARK: Internal

  /// Downloads remote changes from Supabase to local SwiftData.
  /// Fetches all entities updated since lastSyncTime.
  /// Uses a 1-second overlap window to prevent edge-case skips from timestamp precision.
  func syncDown(context: ModelContext) async throws {
    let lastSync = lastSyncTime ?? Date.distantPast
    // Subtract 1 second to create overlap window - prevents missing records
    // when updated_at equals lastSyncTime exactly (common with rapid syncs)
    let safeLastSync = lastSync.addingTimeInterval(-1)
    let lastSyncISO = ISO8601DateFormatter().string(from: safeLastSync)
    debugLog.log("syncDown() - fetching records updated since: \(lastSyncISO) (1s buffer applied)", category: .sync)

    // Determine if we should run full reconciliation
    // Run on first sync (no lastSyncTime) to ensure clean slate
    let shouldReconcile = lastSyncTime == nil
    if shouldReconcile {
      debugLog.log(
        "Warning: First sync detected - will run FULL RECONCILIATION to remove orphan local records",
        category: .sync
      )
    }

    // Sync in order: ListingTypes -> ActivityTemplates -> Users -> Properties -> Listings -> Tasks -> Activities -> TaskAssignees -> ActivityAssignees -> Notes
    // Types/Templates first since Listings reference them
    debugLog.log(
      "Sync order: ListingTypes -> ActivityTemplates -> Users -> Properties -> Listings -> Tasks -> Activities -> TaskAssignees -> ActivityAssignees -> Notes",
      category: .sync
    )

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

    // Reconciliation for all entity types - catches any records missed by incremental sync
    // This ensures data integrity regardless of lastSyncTime state (e.g., after DB reset)
    debugLog.startTiming("reconcileMissingListings")
    _ = try await entitySyncHandler.reconcileMissingListings(context: context)
    debugLog.endTiming("reconcileMissingListings")

    debugLog.startTiming("reconcileMissingTasks")
    _ = try await entitySyncHandler.reconcileMissingTasks(context: context)
    debugLog.endTiming("reconcileMissingTasks")

    debugLog.startTiming("reconcileMissingActivities")
    _ = try await entitySyncHandler.reconcileMissingActivities(context: context)
    debugLog.endTiming("reconcileMissingActivities")

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

  /// Uploads local changes from SwiftData to Supabase.
  /// Pushes all pending entities to the server.
  func syncUp(context: ModelContext) async throws {
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

    // CRITICAL: Capture pending task/activity IDs BEFORE syncing them.
    // After sync, tasks/activities are marked as .synced, so assignee sync would find no pending
    // parents and skip syncing assignees. By capturing IDs here, we ensure assignees are synced
    // for all entities that were pending at the START of this sync cycle.
    // NOTE: Task/activity sync now uses UPSERT (not DELETE+INSERT) to avoid CASCADE delete of assignees.
    let pendingTaskIds = try capturePendingTaskIds(context: context)
    let pendingActivityIds = try capturePendingActivityIds(context: context)
    debugLog.log(
      "Captured pending IDs - Tasks: \(pendingTaskIds.count), Activities: \(pendingActivityIds.count)",
      category: .sync
    )

    // Sync in FK dependency order: Users first (owners), then Properties, then Listings, then Tasks/Activities
    try await entitySyncHandler.syncUpUsers(context: context)
    try await entitySyncHandler.syncUpProperties(context: context)
    try await entitySyncHandler.syncUpListings(context: context)
    try await entitySyncHandler.syncUpTasks(context: context)
    try await entitySyncHandler.syncUpActivities(context: context)
    // Pass pre-captured IDs to ensure assignees are synced even though parents are now .synced
    try await entitySyncHandler.syncUpTaskAssignees(context: context, taskIdsToSync: pendingTaskIds)
    try await entitySyncHandler.syncUpActivityAssignees(context: context, activityIdsToSync: pendingActivityIds)
    try await entitySyncHandler.syncUpNotes(context: context)

    // CRITICAL FIX: Re-mark synced tasks/activities after assignee sync completes.
    // Assignee sync can modify Task/Activity relationship arrays (e.g., deleting duplicates),
    // which SwiftData's dirty tracking may interpret as modifications. This second pass
    // ensures the syncState is definitively set to .synced AFTER all relationship
    // modifications are complete.
    //
    // Note: With the shouldSuppressPending guard in markPending(), this should rarely be needed,
    // but we keep it as a safety net for edge cases where SwiftData dirty tracking occurs
    // outside of markPending() calls.
    try finalizeTaskSyncState(context: context, taskIds: pendingTaskIds)
    try finalizeActivitySyncState(context: context, activityIds: pendingActivityIds)

    // ADDITIONAL SAFETY: Finalize listings that were pending at sync start
    try finalizeListingSyncState(context: context)

    debugLog.log("syncUp() complete", category: .sync)
  }

  // MARK: Private

  // MARK: - Private Helpers

  /// Captures IDs of pending tasks before sync. This is critical because task sync marks tasks as
  /// synced, but we need to sync their assignees afterward.
  private func capturePendingTaskIds(context: ModelContext) throws -> Set<UUID> {
    let descriptor = FetchDescriptor<TaskItem>()
    let allTasks = try context.fetch(descriptor)
    let pendingTasks = allTasks.filter { $0.syncState == .pending || $0.syncState == .failed }
    return Set(pendingTasks.map { $0.id })
  }

  /// Captures IDs of pending activities before sync. This is critical because activity sync marks
  /// activities as synced, but we need to sync their assignees afterward.
  private func capturePendingActivityIds(context: ModelContext) throws -> Set<UUID> {
    let descriptor = FetchDescriptor<Activity>()
    let allActivities = try context.fetch(descriptor)
    let pendingActivities = allActivities.filter { $0.syncState == .pending || $0.syncState == .failed }
    return Set(pendingActivities.map { $0.id })
  }

  /// Final pass to ensure tasks that were synced remain in .synced state.
  /// This runs AFTER all relationship modifications (assignee sync) complete.
  ///
  /// **Why this is needed**: Assignee sync operations can modify Task's `assignees` relationship
  /// array (e.g., deleting duplicate local assignees). SwiftData's dirty tracking may see these
  /// as modifications to the Task, even though we don't call `markPending()`. By re-asserting
  /// `.synced` state here, we ensure the final persisted state is correct.
  private func finalizeTaskSyncState(context: ModelContext, taskIds: Set<UUID>) throws {
    guard !taskIds.isEmpty else { return }

    let descriptor = FetchDescriptor<TaskItem>()
    let allTasks = try context.fetch(descriptor)
    let tasksToFinalize = allTasks.filter { taskIds.contains($0.id) }

    var finalizedCount = 0
    for task in tasksToFinalize {
      // Only re-mark if the task was supposed to be synced but drifted to pending
      // Don't override .failed state (those need retry)
      if task.syncState == .pending {
        task.syncState = .synced
        finalizedCount += 1
        debugLog.log("    FINALIZE_SYNCED task=\(task.id) (was pending after assignee sync)", category: .sync)
      }
    }

    if finalizedCount > 0 {
      debugLog.log("  Finalized \(finalizedCount) tasks to .synced state after assignee sync", category: .sync)
    }
  }

  /// Final pass to ensure activities that were synced remain in .synced state.
  /// This runs AFTER all relationship modifications (assignee sync) complete.
  private func finalizeActivitySyncState(context: ModelContext, activityIds: Set<UUID>) throws {
    guard !activityIds.isEmpty else { return }

    let descriptor = FetchDescriptor<Activity>()
    let allActivities = try context.fetch(descriptor)
    let activitiesToFinalize = allActivities.filter { activityIds.contains($0.id) }

    var finalizedCount = 0
    for activity in activitiesToFinalize {
      // Only re-mark if the activity was supposed to be synced but drifted to pending
      // Don't override .failed state (those need retry)
      if activity.syncState == .pending {
        activity.syncState = .synced
        finalizedCount += 1
        debugLog.log("    FINALIZE_SYNCED activity=\(activity.id) (was pending after assignee sync)", category: .sync)
      }
    }

    if finalizedCount > 0 {
      debugLog.log("  Finalized \(finalizedCount) activities to .synced state after assignee sync", category: .sync)
    }
  }

  /// Final pass to ensure listings remain in .synced state after relationship reconciliation.
  /// This catches listings that may have been inadvertently marked pending during owner/property
  /// relationship establishment.
  ///
  /// **Note**: With the shouldSuppressPending guard now in place, this is primarily a safety net.
  /// Listings that were successfully synced up but then had their owner relationship modified
  /// should not flip back to pending because markPending() checks shouldSuppressPending.
  private func finalizeListingSyncState(context: ModelContext) throws {
    let descriptor = FetchDescriptor<Listing>()
    let allListings = try context.fetch(descriptor)

    var finalizedCount = 0
    for listing in allListings {
      // Only re-mark synced listings that somehow drifted to pending during sync
      // Key insight: A listing that was just successfully synced (syncedAt is recent) but is now
      // marked pending with no user changes is a victim of relationship dirty tracking
      if listing.syncState == .pending, let syncedAt = listing.syncedAt {
        // If syncedAt is within the last 30 seconds, this was likely dirty-tracking induced
        if Date().timeIntervalSince(syncedAt) < 30 {
          listing.syncState = .synced
          finalizedCount += 1
          debugLog.log(
            "    FINALIZE_SYNCED listing=\(listing.id) (was pending but recently synced at \(syncedAt))",
            category: .sync
          )
        }
      }
    }

    if finalizedCount > 0 {
      debugLog.log("  Finalized \(finalizedCount) listings to .synced state after relationship reconciliation", category: .sync)
    }
  }
}
