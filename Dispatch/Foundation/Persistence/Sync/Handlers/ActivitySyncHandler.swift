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
      .gt("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "activities", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting activity \(index + 1)/\(dtos.count): \(dto.id) - \(dto.title)", category: .sync)
      try upsertActivity(dto: dto, context: context, establishListingRelationship: establishListingRelationship)
    }
  }

  // MARK: - SyncUp Activities

  /// Syncs activities using explicit DELETE + INSERT to ensure proper audit logging.
  ///
  /// The audit system only captures INSERT and DELETE events, not UPDATE events.
  /// Using UPSERT would trigger UPDATE when modifying an activity, which wouldn't
  /// appear in the audit history. This method ensures:
  /// - Soft-deleting an activity generates DELETE then INSERT audit events
  /// - Modifying an activity generates DELETE then INSERT audit events
  /// - Creating a new activity generates an INSERT audit event
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

    // Fetch server-side activities to determine which exist
    let pendingIds = pendingActivities.map { $0.id }
    let serverActivities: [ActivityDTO] = try await supabase
      .from("activities")
      .select()
      .in("id", values: pendingIds.map { $0.uuidString })
      .execute()
      .value

    let serverActivityIds = Set(serverActivities.map { $0.id })
    debugLog.log(
      "  Local pending: \(pendingActivities.count), Server existing: \(serverActivityIds.count)",
      category: .sync
    )

    // Mark as in-flight before sync to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markActivitiesInFlight(Set(pendingActivities.map { $0.id }))
    defer { dependencies.conflictResolver.clearActivitiesInFlight() }

    // Process each pending activity with DELETE + INSERT pattern
    for activity in pendingActivities {
      let dto = ActivityDTO(from: activity)
      let existsOnServer = serverActivityIds.contains(activity.id)

      do {
        // DELETE if exists on server (handles modification and soft-delete cases)
        if existsOnServer {
          try await supabase
            .from("activities")
            .delete()
            .eq("id", value: activity.id.uuidString)
            .execute()
          debugLog.log("    Deleted existing activity \(activity.id) for re-insert", category: .sync)
        }

        // INSERT the activity (generates INSERT audit event)
        try await supabase
          .from("activities")
          .insert(dto)
          .execute()
        activity.markSynced()
        debugLog.log("    Inserted activity \(activity.id) - \(activity.title)", category: .sync)
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
      .gt("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "activity_assignees", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting activity assignee \(index + 1)/\(dtos.count): \(dto.id)", category: .sync)
      try upsertActivityAssignee(dto: dto, context: context, establishActivityRelationship: establishActivityRelationship)
    }
  }

  // MARK: - SyncUp ActivityAssignees

  /// Syncs activity assignees using explicit DELETE + INSERT to ensure proper audit logging.
  ///
  /// The audit system only captures INSERT and DELETE events, not UPDATE events.
  /// Using UPSERT would trigger UPDATE when re-claiming an activity, which wouldn't
  /// appear in the audit history. This method ensures:
  /// - Unclaiming generates a DELETE audit event
  /// - Claiming (including re-claiming) generates an INSERT audit event
  ///
  /// - Parameter activityIdsToSync: Pre-captured activity IDs to sync assignees for. If nil, falls back to
  ///   checking current pending activities (legacy behavior). This parameter is critical because activity sync
  ///   marks activities as synced BEFORE assignee sync runs, so we must capture pending IDs at the start of
  ///   the sync cycle.
  func syncUpActivityAssignees(context: ModelContext, activityIdsToSync: Set<UUID>? = nil) async throws {
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
      "syncUpActivityAssignees() - processing assignees for \(pendingActivityIds.count) activities",
      category: .sync
    )

    // Get current local assignees for pending activities
    let assigneeDescriptor = FetchDescriptor<ActivityAssignee>()
    let allLocalAssignees = try context.fetch(assigneeDescriptor)
    let localAssigneesForPending = allLocalAssignees.filter { pendingActivityIds.contains($0.activityId) }

    // Build a map of activity ID -> local assignee IDs
    var localAssigneesByActivity: [UUID: Set<UUID>] = [:]
    var localAssigneesById: [UUID: ActivityAssignee] = [:]
    for assignee in localAssigneesForPending {
      localAssigneesByActivity[assignee.activityId, default: []].insert(assignee.id)
      localAssigneesById[assignee.id] = assignee
    }

    // Fetch server-side assignees for these activities
    let serverAssignees: [ActivityAssigneeDTO] = try await supabase
      .from("activity_assignees")
      .select()
      .in("activity_id", values: pendingActivityIds.map { $0.uuidString })
      .execute()
      .value

    // Build a map of activity ID -> server assignee IDs
    var serverAssigneesByActivity: [UUID: Set<UUID>] = [:]
    for dto in serverAssignees {
      serverAssigneesByActivity[dto.activityId, default: []].insert(dto.id)
    }

    debugLog.log(
      "  Local assignees: \(localAssigneesForPending.count), Server assignees: \(serverAssignees.count)",
      category: .sync
    )

    // Mark local assignees as in-flight to prevent realtime echo
    dependencies.conflictResolver.markActivityAssigneesInFlight(Set(localAssigneesById.keys))
    defer { dependencies.conflictResolver.clearActivityAssigneesInFlight() }

    // Process each pending activity
    for activityId in pendingActivityIds {
      let localIds = localAssigneesByActivity[activityId] ?? []
      let serverIds = serverAssigneesByActivity[activityId] ?? []

      // 1. DELETE: Assignees on server but not local (user unclaimed)
      let toDelete = serverIds.subtracting(localIds)
      if !toDelete.isEmpty {
        debugLog.log("  Activity \(activityId): deleting \(toDelete.count) removed assignees", category: .sync)
        for assigneeId in toDelete {
          do {
            try await supabase
              .from("activity_assignees")
              .delete()
              .eq("id", value: assigneeId.uuidString)
              .execute()
            debugLog.log("    Deleted assignee \(assigneeId)", category: .sync)
          } catch {
            debugLog.error("    Failed to delete assignee \(assigneeId): \(error.localizedDescription)")
          }
        }
      }

      // 2. DELETE + INSERT: For local assignees, delete first (if exists) then insert
      // This ensures INSERT audit events even for re-claims
      for assigneeId in localIds {
        guard let assignee = localAssigneesById[assigneeId] else { continue }
        let dto = ActivityAssigneeDTO(model: assignee)

        do {
          // Delete if exists on server (handles re-claim case)
          if serverIds.contains(assigneeId) {
            try await supabase
              .from("activity_assignees")
              .delete()
              .eq("id", value: assigneeId.uuidString)
              .execute()
            debugLog.log("    Deleted existing assignee \(assigneeId) for re-insert", category: .sync)
          }

          // Insert the assignee (generates INSERT audit event)
          try await supabase
            .from("activity_assignees")
            .insert(dto)
            .execute()
          assignee.markSynced()
          debugLog.log("    Inserted assignee \(assigneeId)", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          assignee.markFailed(message)
          debugLog.error("    Failed to sync assignee \(assigneeId): \(message)")
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
