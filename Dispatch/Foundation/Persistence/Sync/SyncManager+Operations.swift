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

  /// Downloads remote changes from Supabase to local SwiftData.
  /// Fetches all entities updated since lastSyncTime.
  func syncDown(context: ModelContext) async throws {
    let lastSync = lastSyncTime ?? Date.distantPast
    let lastSyncISO = ISO8601DateFormatter().string(from: lastSync)
    debugLog.log("syncDown() - fetching records updated since: \(lastSyncISO)", category: .sync)

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
}
