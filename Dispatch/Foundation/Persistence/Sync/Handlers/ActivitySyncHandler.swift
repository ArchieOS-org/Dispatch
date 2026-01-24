//
//  ActivitySyncHandler.swift
//  Dispatch
//
//  Handles all Activity, ActivityAssignee, and ActivityTemplate sync operations.
//  Extracted from EntitySyncHandler for maintainability.
//

import Foundation
import Supabase
import SwiftData

// MARK: - ActivitySyncHandler

/// Handles Activity, ActivityAssignee, and ActivityTemplate entity sync operations.
@MainActor
final class ActivitySyncHandler: EntitySyncHandlerProtocol {

  // MARK: Lifecycle

  init(dependencies: SyncHandlerDependencies) {
    self.dependencies = dependencies
  }

  // MARK: Internal

  // MARK: - UserDefaults Keys

  static let lastSyncActivityTemplatesKey = "dispatch.lastSyncActivityTemplates"

  let dependencies: SyncHandlerDependencies

  // MARK: - SyncDown Activities

  func syncDown(context: ModelContext, since: String) async throws {
    try await syncDownActivities(context: context, since: since, establishListingRelationship: nil)
  }

  func syncDownActivities(
    context: ModelContext,
    since: String,
    establishListingRelationship: ((Activity, UUID?, ModelContext) throws -> Void)?
  ) async throws {
    debugLog.log("syncDownActivities() - querying Supabase...", category: .sync)
    let dtos: [ActivityDTO] = try await supabase
      .from("activities")
      .select()
      .gte("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "activities", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting activity \(index + 1)/\(dtos.count): \(dto.id) - \(dto.title)", category: .sync)
      try upsertActivity(dto: dto, context: context, establishListingRelationship: establishListingRelationship)
    }
  }

  // MARK: - SyncUp Activities

  /// Syncs activities using UPSERT to avoid triggering CASCADE DELETE on foreign keys.
  ///
  /// Previously used DELETE + INSERT for audit logging, but this caused CASCADE DELETE
  /// on activity_assignees FK constraint, wiping out assignees when syncing activities.
  /// UPSERT performs INSERT or UPDATE without DELETE, preserving related records.
  ///
  /// **Audit Note**: UPSERT triggers UPDATE events for existing rows. The audit system
  /// handles UPDATE events correctly via database triggers.
  func syncUp(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<Activity>()
    let allActivities = try context.fetch(descriptor)
    debugLog.log("syncUpActivities() - fetched \(allActivities.count) total activities from SwiftData", category: .sync)

    let pendingActivities = allActivities.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "activities",
      count: pendingActivities.count,
      details: "of \(allActivities.count) total"
    )

    guard !pendingActivities.isEmpty else {
      debugLog.log("  No pending activities to sync", category: .sync)
      return
    }

    debugLog.log("  Local pending: \(pendingActivities.count)", category: .sync)

    // Mark as in-flight before sync to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markActivitiesInFlight(Set(pendingActivities.map { $0.id }))
    defer { dependencies.conflictResolver.clearActivitiesInFlight() }

    // Process each pending activity with UPSERT (INSERT or UPDATE, no DELETE)
    for activity in pendingActivities {
      let dto = ActivityDTO(from: activity)

      do {
        // UPSERT: Insert if new, update if exists - no CASCADE DELETE triggered
        // Discard result to prevent type inference causing decode errors
        _ = try await supabase
          .from("activities")
          .upsert(dto)
          .execute()
        activity.markSynced()
        debugLog.log("    Upserted activity \(activity.id) - \(activity.title)", category: .sync)
      } catch {
        let message = dependencies.userFacingMessage(for: error)
        activity.markFailed(message)
        debugLog.error("    Failed to sync activity \(activity.id): \(message)")
      }
    }

    debugLog.log("syncUpActivities() complete", category: .sync)
  }

  // MARK: - Upsert Activity

  /// Upsert an activity from remote DTO. Relationship establishment delegated to coordinator.
  func upsertActivity(
    dto: ActivityDTO,
    context: ModelContext,
    establishListingRelationship: ((Activity, UUID?, ModelContext) throws -> Void)? = nil
  ) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<Activity>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip ALL updates if local-authoritative
      if
        dependencies.conflictResolver.isLocalAuthoritative(
          existing,
          inFlight: dependencies.conflictResolver.isActivityInFlight(existing.id)
        )
      {
        debugLog.log(
          "[SyncDown] Skip update for activity \(dto.id) - local-authoritative (state=\(existing.syncState))",
          category: .sync
        )
        return
      }

      debugLog.log("    UPDATE existing activity: \(dto.id)", category: .sync)
      existing.title = dto.title
      existing.activityDescription = dto.description ?? ""
      existing.dueDate = dto.dueDate
      existing.status = ActivityStatus(rawValue: dto.status) ?? .open
      existing.duration = dto.durationMinutes.map { TimeInterval($0 * 60) }
      existing.completedAt = dto.completedAt
      existing.deletedAt = dto.deletedAt
      existing.updatedAt = dto.updatedAt
      existing.listingId = dto.listing
      if let establishListing = establishListingRelationship {
        try establishListing(existing, dto.listing, context)
      }
      existing.markSynced()
    } else {
      debugLog.log("    INSERT new activity: \(dto.id)", category: .sync)
      let newActivity = dto.toModel()
      newActivity.markSynced()
      context.insert(newActivity)
      if let establishListing = establishListingRelationship {
        try establishListing(newActivity, dto.listing, context)
      }
    }
  }

  // MARK: - Reconcile Missing Activities

  /// Reconciles missing activities - finds activities on server that don't exist locally and fetches them.
  /// This is a failsafe to catch activities that were missed due to watermark issues or other sync gaps.
  /// Runs on every sync to ensure data consistency.
  func reconcileMissingActivities(context: ModelContext) async throws -> Int {
    // 1. Fetch all activity IDs from server (lightweight query)
    let remoteDTOs: [IDOnlyDTO] = try await supabase
      .from("activities")
      .select("id")
      .execute()
      .value
    let remoteIds = Set(remoteDTOs.map { $0.id })
    debugLog.log("  Remote activities: \(remoteIds.count)", category: .sync)

    // 2. Get all local activity IDs
    let localDescriptor = FetchDescriptor<Activity>()
    let localActivities = try context.fetch(localDescriptor)
    let localIds = Set(localActivities.map { $0.id })
    debugLog.log("  Local activities: \(localIds.count)", category: .sync)

    // 3. Find IDs that exist on server but not locally
    let missingIds = remoteIds.subtracting(localIds)

    guard !missingIds.isEmpty else {
      debugLog.log("  No missing activities", category: .sync)
      return 0
    }

    debugLog.log("  Warning: Found \(missingIds.count) missing activities, fetching...", category: .sync)

    // 4. Fetch full activity data for missing IDs (batch query)
    let missingDTOs: [ActivityDTO] = try await supabase
      .from("activities")
      .select()
      .in("id", values: Array(missingIds).map { $0.uuidString })
      .execute()
      .value

    // 5. Upsert missing activities
    for dto in missingDTOs {
      try upsertActivity(dto: dto, context: context, establishListingRelationship: nil)
    }

    debugLog.log("  Reconciled \(missingDTOs.count) missing activities", category: .sync)
    return missingDTOs.count
  }

  // MARK: - Delete Activity

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

  // MARK: - SyncDown ActivityAssignees

  func syncDownActivityAssignees(
    context: ModelContext,
    since: String,
    establishActivityRelationship: ((ActivityAssignee, UUID, ModelContext) throws -> Void)?
  ) async throws {
    debugLog.log("syncDownActivityAssignees() - querying Supabase...", category: .sync)
    let dtos: [ActivityAssigneeDTO] = try await supabase
      .from("activity_assignees")
      .select()
      .gte("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "activity_assignees", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting activity assignee \(index + 1)/\(dtos.count): \(dto.id)", category: .sync)
      try upsertActivityAssignee(dto: dto, context: context, establishActivityRelationship: establishActivityRelationship)
    }
  }

  // MARK: - SyncUp ActivityAssignees

  /// Syncs activity assignees using UPSERT with local deduplication.
  ///
  /// **Problem Solved**: Multiple local assignees can exist for the same (activity_id, user_id) composite key,
  /// causing duplicate sync operations and inconsistent state.
  ///
  /// **Solution**:
  /// 1. Deduplicate locally first - group by (activity_id, user_id), keep newest (by updatedAt), delete rest
  /// 2. Use UPSERT with `onConflict: "activity_id,user_id"` for efficient single-operation sync
  /// 3. Process each composite key exactly once
  ///
  /// **Audit Note**: UPSERT triggers INSERT for new records and UPDATE for existing records.
  /// The audit system captures all these events via database triggers.
  ///
  /// **IMPORTANT**: This method only syncs the CURRENT USER's assignee records.
  /// RLS policies only allow users to INSERT their own assignee records (or others'
  /// if they are activity creator/listing owner). To avoid permission errors, each user
  /// manages their own claim/unclaim independently.
  ///
  /// - Parameter activityIdsToSync: Pre-captured activity IDs to sync assignees for. If nil, falls back to
  ///   checking current pending activities (legacy behavior). This parameter is critical because activity sync
  ///   marks activities as synced BEFORE assignee sync runs, so we must capture pending IDs at the start of
  ///   the sync cycle.
  func syncUpActivityAssignees(context: ModelContext, activityIdsToSync: Set<UUID>? = nil) async throws {
    // Get current user ID - required for filtering assignees
    guard let currentUserId = dependencies.getCurrentUserID() else {
      debugLog.log("syncUpActivityAssignees() - no current user, skipping", category: .sync)
      return
    }

    // Use pre-captured IDs if provided, otherwise fall back to current pending activities
    let pendingActivityIds: [UUID]
    if let preCapturedIds = activityIdsToSync {
      pendingActivityIds = Array(preCapturedIds)
      debugLog.log(
        "syncUpActivityAssignees() - using \(pendingActivityIds.count) pre-captured activity IDs",
        category: .sync
      )
    } else {
      // Legacy fallback: Find activities that have pending changes (their assignees may have changed)
      let activityDescriptor = FetchDescriptor<Activity>()
      let allActivities = try context.fetch(activityDescriptor)
      let pendingActivities = allActivities.filter { $0.syncState == .pending || $0.syncState == .failed }
      pendingActivityIds = pendingActivities.map { $0.id }
    }

    guard !pendingActivityIds.isEmpty else {
      debugLog.log("syncUpActivityAssignees() - no activities to process, skipping", category: .sync)
      return
    }

    debugLog.log(
      "syncUpActivityAssignees() - processing assignees for \(pendingActivityIds.count) activities (user: \(currentUserId))",
      category: .sync
    )

    // Get current local assignees for pending activities - ONLY for current user
    let assigneeDescriptor = FetchDescriptor<ActivityAssignee>()
    let allLocalAssignees = try context.fetch(assigneeDescriptor)
    let localAssigneesForPending = allLocalAssignees.filter {
      pendingActivityIds.contains($0.activityId) && $0.userId == currentUserId
    }

    // =========================================================================
    // STEP 1: Local Deduplication
    // Group by composite key (activity_id, user_id), keep newest by updatedAt, delete rest
    // =========================================================================
    var assigneesByCompositeKey: [String: [ActivityAssignee]] = [:]
    for assignee in localAssigneesForPending {
      let compositeKey = "\(assignee.activityId)-\(assignee.userId)"
      assigneesByCompositeKey[compositeKey, default: []].append(assignee)
    }

    // Deduplicate: keep newest, delete duplicates
    var dedupedAssignees: [String: ActivityAssignee] = [:]
    var duplicatesDeleted = 0
    for (compositeKey, assignees) in assigneesByCompositeKey {
      if assignees.count > 1 {
        // Sort by updatedAt descending, keep the newest
        let sorted = assignees.sorted { $0.updatedAt > $1.updatedAt }
        let keeper = sorted[0]
        dedupedAssignees[compositeKey] = keeper

        // Delete the duplicates from local DB
        for duplicate in sorted.dropFirst() {
          debugLog.log(
            "    Deleting local duplicate assignee \(duplicate.id) for composite key \(compositeKey)",
            category: .sync
          )
          context.delete(duplicate)
          duplicatesDeleted += 1
        }
      } else if let single = assignees.first {
        dedupedAssignees[compositeKey] = single
      }
    }

    if duplicatesDeleted > 0 {
      debugLog.log(
        "  Deduplication: removed \(duplicatesDeleted) local duplicates, \(dedupedAssignees.count) unique assignees remain",
        category: .sync
      )
    }

    // Build lookup by ID for the deduplicated set
    var localAssigneesById: [UUID: ActivityAssignee] = [:]
    for assignee in dedupedAssignees.values {
      localAssigneesById[assignee.id] = assignee
    }

    // Fetch server-side assignees for these activities - ONLY current user's records
    let serverAssignees: [ActivityAssigneeDTO] = try await supabase
      .from("activity_assignees")
      .select()
      .in("activity_id", values: pendingActivityIds.map { $0.uuidString })
      .eq("user_id", value: currentUserId.uuidString)
      .execute()
      .value

    // Build a set of (activity_id, user_id) composite keys that exist on server
    var serverCompositeKeys: Set<String> = []
    for dto in serverAssignees {
      serverCompositeKeys.insert("\(dto.activityId)-\(dto.userId)")
    }

    debugLog.log(
      "  Local assignees (after dedup): \(dedupedAssignees.count), Server assignees (current user): \(serverAssignees.count)",
      category: .sync
    )

    // Mark local assignees as in-flight to prevent realtime echo
    dependencies.conflictResolver.markActivityAssigneesInFlight(Set(localAssigneesById.keys))
    defer { dependencies.conflictResolver.clearActivityAssigneesInFlight() }

    // =========================================================================
    // STEP 2: Compute desired state per activity
    // Local composite keys = what should exist, Server keys - Local keys = what to delete
    // =========================================================================
    let localCompositeKeys = Set(dedupedAssignees.keys)

    // Process each pending activity
    for activityId in pendingActivityIds {
      // Find server keys for this activity that are NOT in local (user unclaimed)
      let serverKeysForActivity = serverCompositeKeys.filter { $0.hasPrefix("\(activityId)-") }
      let localKeysForActivity = localCompositeKeys.filter { $0.hasPrefix("\(activityId)-") }
      let toDeleteKeys = serverKeysForActivity.subtracting(localKeysForActivity)

      // DELETE: Current user's assignee on server but not local (user unclaimed)
      if !toDeleteKeys.isEmpty {
        debugLog.log(
          "  Activity \(activityId): deleting \(toDeleteKeys.count) removed assignees (current user)",
          category: .sync
        )
        for compositeKey in toDeleteKeys {
          // Parse the composite key to get activity_id and user_id
          let parts = compositeKey.split(separator: "-")
          guard
            parts.count == 2,
            let deleteActivityId = UUID(uuidString: String(parts[0])),
            let deleteUserId = UUID(uuidString: String(parts[1]))
          else {
            debugLog.error("    Invalid composite key format: \(compositeKey)")
            continue
          }
          do {
            try await supabase
              .from("activity_assignees")
              .delete()
              .eq("activity_id", value: deleteActivityId.uuidString)
              .eq("user_id", value: deleteUserId.uuidString)
              .execute()
            debugLog.log("    Deleted assignee with composite key \(compositeKey)", category: .sync)
          } catch {
            debugLog.error(
              "    Failed to delete assignee with composite key \(compositeKey): \(error.localizedDescription)"
            )
          }
        }
      }

      // UPSERT: For each local assignee (deduplicated), upsert to server
      for compositeKey in localKeysForActivity {
        guard let assignee = dedupedAssignees[compositeKey] else { continue }
        let dto = ActivityAssigneeDTO(model: assignee)

        do {
          // UPSERT with onConflict ensures single operation:
          // - INSERT if (activity_id, user_id) doesn't exist
          // - UPDATE if (activity_id, user_id) already exists
          _ = try await supabase
            .from("activity_assignees")
            .upsert(dto, onConflict: "activity_id,user_id")
            .execute()
          assignee.markSynced()
          debugLog.log("    Upserted assignee \(assignee.id) for composite key \(compositeKey)", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          assignee.markFailed(message)
          debugLog.error("    Failed to upsert assignee \(assignee.id): \(message)")
        }
      }
    }

    debugLog.log("syncUpActivityAssignees() complete", category: .sync)
  }

  // MARK: - Upsert ActivityAssignee

  /// Upsert an activity assignee from remote DTO. Relationship establishment delegated to coordinator.
  func upsertActivityAssignee(
    dto: ActivityAssigneeDTO,
    context: ModelContext,
    establishActivityRelationship: ((ActivityAssignee, UUID, ModelContext) throws -> Void)? = nil
  ) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<ActivityAssignee>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip ALL updates if local-authoritative
      if
        dependencies.conflictResolver.isLocalAuthoritative(
          existing,
          inFlight: dependencies.conflictResolver.isActivityAssigneeInFlight(existing.id)
        )
      {
        debugLog.log(
          "[SyncDown] Skip update for activity assignee \(dto.id) - local-authoritative (state=\(existing.syncState))",
          category: .sync
        )
        return
      }

      debugLog.log("    UPDATE existing activity assignee: \(dto.id)", category: .sync)
      existing.activityId = dto.activityId
      existing.userId = dto.userId
      existing.assignedBy = dto.assignedBy
      existing.assignedAt = dto.assignedAt
      existing.updatedAt = dto.updatedAt
      existing.markSynced()

      // Establish relationship with parent activity
      if let establishActivity = establishActivityRelationship {
        try establishActivity(existing, dto.activityId, context)
      }
    } else {
      debugLog.log("    INSERT new activity assignee: \(dto.id)", category: .sync)
      let newAssignee = dto.toModel()
      newAssignee.markSynced()
      context.insert(newAssignee)
      if let establishActivity = establishActivityRelationship {
        try establishActivity(newAssignee, dto.activityId, context)
      }
    }
  }

  // MARK: - SyncDown ActivityTemplates

  func syncDownActivityTemplates(context: ModelContext) async throws {
    // Per-table watermark with 2s overlap window
    let lastSync = (
      dependencies.mode == .live
        ? UserDefaults.standard.object(forKey: Self.lastSyncActivityTemplatesKey) as? Date
        : nil
    ) ?? Date.distantPast
    let safeDate = lastSync.addingTimeInterval(-2)
    let safeISO = ISO8601DateFormatter().string(from: safeDate)
    debugLog.log("syncDownActivityTemplates() - fetching records updated since: \(safeISO)", category: .sync)

    let dtos: [ActivityTemplateDTO] = try await supabase
      .from("activity_templates")
      .select()
      .gte("updated_at", value: safeISO)
      .execute()
      .value
    debugLog.logSyncOperation(operation: "FETCH", table: "activity_templates", count: dtos.count)

    // Get all local ListingTypeDefinition IDs for FK validation
    let typesDescriptor = FetchDescriptor<ListingTypeDefinition>()
    let localTypes = try context.fetch(typesDescriptor)
    let localTypeIds = Set(localTypes.map { $0.id })

    var deferredTemplates = [ActivityTemplateDTO]()

    // First pass: process templates with valid FK
    for dto in dtos {
      // FK validation: skip if type doesn't exist locally
      guard localTypeIds.contains(dto.listingTypeId) else {
        debugLog.log("    DEFER (missing type): \(dto.id)", category: .sync)
        deferredTemplates.append(dto)
        continue
      }

      try upsertActivityTemplate(dto: dto, context: context, localTypes: localTypes)
    }

    // Second pass: retry deferred templates (types may have been inserted in first pass)
    if !deferredTemplates.isEmpty {
      debugLog.log("Second pass for \(deferredTemplates.count) deferred templates...", category: .sync)
      let refreshedTypesDescriptor = FetchDescriptor<ListingTypeDefinition>()
      let refreshedTypes = try context.fetch(refreshedTypesDescriptor)
      let refreshedTypeIds = Set(refreshedTypes.map { $0.id })

      for dto in deferredTemplates {
        if refreshedTypeIds.contains(dto.listingTypeId) {
          try upsertActivityTemplate(dto: dto, context: context, localTypes: refreshedTypes)
        } else {
          debugLog.log("    STILL MISSING TYPE: \(dto.id) -> \(dto.listingTypeId)", category: .sync)
        }
      }
    }

    // Update per-table watermark
    if dependencies.mode == .live {
      UserDefaults.standard.set(Date(), forKey: Self.lastSyncActivityTemplatesKey)
    }
  }

  // MARK: - SyncUp ActivityTemplates

  func syncUpActivityTemplates(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<ActivityTemplate>()
    let allTemplates = try context.fetch(descriptor)
    debugLog.log("syncUpActivityTemplates() - fetched \(allTemplates.count) total", category: .sync)

    let pendingTemplates = allTemplates.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "activity_templates",
      count: pendingTemplates.count,
      details: "of \(allTemplates.count) total"
    )

    guard !pendingTemplates.isEmpty else {
      debugLog.log("  No pending activity templates to sync", category: .sync)
      return
    }

    // Batch upsert first
    do {
      let dtos = pendingTemplates.map { ActivityTemplateDTO(from: $0) }
      debugLog.log("  Batch upserting \(dtos.count) activity templates...", category: .sync)
      try await supabase
        .from("activity_templates")
        .upsert(dtos)
        .execute()
      debugLog.log("  Batch upsert successful", category: .sync)

      for template in pendingTemplates {
        template.markSynced()
      }
    } catch {
      // Individual fallback
      debugLog.log("Batch activity template sync failed, trying individually: \(error.localizedDescription)", category: .error)

      for template in pendingTemplates {
        do {
          let dto = ActivityTemplateDTO(from: template)
          try await supabase
            .from("activity_templates")
            .upsert([dto])
            .execute()
          template.markSynced()
          debugLog.log("  ActivityTemplate \(template.id) synced", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          template.markFailed(message)
          debugLog.error("  ActivityTemplate \(template.id) sync failed: \(message)")
        }
      }
    }
  }

  // MARK: - Upsert ActivityTemplate

  func upsertActivityTemplate(
    dto: ActivityTemplateDTO,
    context: ModelContext,
    localTypes: [ListingTypeDefinition]
  ) throws {
    let descriptor = FetchDescriptor<ActivityTemplate>(predicate: #Predicate { $0.id == dto.id })
    let existing = try context.fetch(descriptor).first

    // Pending/failed protection
    if let existing, existing.syncState == .pending || existing.syncState == .failed {
      debugLog.log("    SKIP (pending/failed): \(dto.id)", category: .sync)
      return
    }

    if let existing {
      // UPDATE
      debugLog.log("    UPDATE: \(dto.id) - \(dto.title)", category: .sync)
      existing.title = dto.title
      existing.templateDescription = dto.description
      existing.position = dto.position
      existing.isArchived = dto.isArchived
      existing.audiencesRaw = dto.audiences
      existing.listingTypeId = dto.listingTypeId
      existing.defaultAssigneeId = dto.defaultAssigneeId
      existing.updatedAt = dto.updatedAt
      existing.listingType = localTypes.first { $0.id == dto.listingTypeId }
      existing.markSynced()
    } else {
      // INSERT
      debugLog.log("    INSERT: \(dto.id) - \(dto.title)", category: .sync)
      let newTemplate = dto.toModel()
      newTemplate.listingType = localTypes.first { $0.id == dto.listingTypeId }
      newTemplate.markSynced()
      context.insert(newTemplate)
    }
  }

  // MARK: Private

  /// Lightweight DTO for fetching only IDs from Supabase
  private struct IDOnlyDTO: Codable {
    let id: UUID
  }
}
