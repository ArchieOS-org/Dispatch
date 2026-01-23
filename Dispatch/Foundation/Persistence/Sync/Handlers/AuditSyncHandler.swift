//
//  AuditSyncHandler.swift
//  Dispatch
//
//  Handles all audit-related Supabase RPC calls.
//  The audit schema is private - all access goes through public RPC functions.
//

import Foundation
import Supabase

// MARK: - AuditSyncHandler

@MainActor
final class AuditSyncHandler {

  // MARK: Lifecycle

  init(supabase: SupabaseClient) {
    self.supabase = supabase
  }

  // MARK: Internal

  // MARK: - Fetch History (via RPC)

  /// Fetch audit history for a specific entity via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type, p_entity_id, p_limit)`
  func fetchHistory(
    for entityType: AuditableEntity,
    entityId: UUID,
    limit: Int = 50
  )
    async throws -> [AuditEntry]
  {
    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_entity_history", params: [
        "p_entity_type": entityType.rawValue,
        "p_entity_id": entityId.uuidString,
        "p_limit": String(limit)
      ])
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  // MARK: - Fetch Recently Deleted (via RPC)

  /// Fetch recently deleted items across all entity types via public RPC
  ///
  /// Calls: `get_recently_deleted(p_entity_type, p_limit)`
  func fetchRecentlyDeleted(entityType: AuditableEntity? = nil, limit: Int = 50) async throws
    -> [AuditEntry]
  {
    var params: [String: String] = ["p_limit": String(limit)]
    if let entityType {
      params["p_entity_type"] = entityType.rawValue
    }

    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_recently_deleted", params: params)
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  // MARK: - Fetch Assignee History (via RPC)

  /// Fetch assignment history for a task via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type='task_assignee', p_entity_id, p_limit)`
  func fetchTaskAssigneeHistory(taskId: UUID, limit: Int = 50) async throws -> [AuditEntry] {
    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_entity_history", params: [
        "p_entity_type": AuditableEntity.taskAssignee.rawValue,
        "p_entity_id": taskId.uuidString,
        "p_limit": String(limit)
      ])
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  /// Fetch assignment history for an activity via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type='activity_assignee', p_entity_id, p_limit)`
  func fetchActivityAssigneeHistory(activityId: UUID, limit: Int = 50) async throws -> [AuditEntry] {
    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_entity_history", params: [
        "p_entity_type": AuditableEntity.activityAssignee.rawValue,
        "p_entity_id": activityId.uuidString,
        "p_limit": String(limit)
      ])
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  // MARK: - Fetch Related History (Notes)

  /// Fetch note history for a parent entity via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type='note', p_entity_id, p_limit)`
  /// Note: The RPC filters by parent_id in the old_row/new_row JSONB
  func fetchNotesHistory(parentType _: AuditableEntity, parentId: UUID, limit: Int = 50)
    async throws -> [AuditEntry]
  {
    let dtos: [AuditEntryDTO] = try await supabase
      .rpc("get_entity_history", params: [
        "p_entity_type": AuditableEntity.note.rawValue,
        "p_entity_id": parentId.uuidString,
        "p_limit": String(limit)
      ])
      .execute()
      .value

    return dtos.map { $0.toModel() }
  }

  // MARK: - Fetch Combined History

  /// Fetch combined history for an entity including related entries (assignments or notes)
  ///
  /// For tasks: returns task history + assignment history, merged and sorted by date
  /// For activities: returns activity history + assignment history
  /// For listings/properties: returns entity history + note history
  func fetchCombinedHistory(
    for entityType: AuditableEntity,
    entityId: UUID,
    limit: Int = 50
  )
    async throws -> [AuditEntry]
  {
    // Fetch primary entity history
    async let primaryHistoryTask = fetchHistory(for: entityType, entityId: entityId, limit: limit)

    // Fetch related history based on entity type
    let relatedHistoryTask: Task<[AuditEntry], Error> =
      switch entityType {
      case .task:
        Task { try await fetchTaskAssigneeHistory(taskId: entityId, limit: limit) }

      case .activity:
        Task {
          try await fetchActivityAssigneeHistory(activityId: entityId, limit: limit)
        }

      case .listing, .property:
        Task {
          try await fetchNotesHistory(parentType: entityType, parentId: entityId, limit: limit)
        }

      default:
        // No related history for users or related entities themselves
        Task { [] }
      }

    // Await both results
    let primaryHistory = try await primaryHistoryTask
    let relatedHistory = try await relatedHistoryTask.value

    // Merge and sort by changedAt descending
    let combined = (primaryHistory + relatedHistory).sorted { $0.changedAt > $1.changedAt }

    // Apply limit to combined result
    return Array(combined.prefix(limit))
  }

  // MARK: - Restore Entity (via RPC)

  /// Restore a deleted entity via unified RPC
  ///
  /// Calls: `restore_entity(p_entity_type, p_entity_id)`
  /// Returns: The restored entity's ID
  func restoreEntity(_ entityType: AuditableEntity, entityId: UUID) async throws -> UUID {
    do {
      return try await supabase
        .rpc("restore_entity", params: [
          "p_entity_type": entityType.rawValue,
          "p_entity_id": entityId.uuidString
        ])
        .execute()
        .value
    } catch let error as PostgrestError {
      throw RestoreError.from(error)
    }
  }

  // MARK: Private

  private let supabase: SupabaseClient

}
