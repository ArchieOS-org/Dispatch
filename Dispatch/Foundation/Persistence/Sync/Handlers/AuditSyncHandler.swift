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
    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchHistory called: entityType=\(entityType.rawValue), entityId=\(entityId), limit=\(limit)",
      category: .sync
    )
    #endif

    do {
      let dtos: [AuditEntryDTO] = try await supabase
        .rpc("get_entity_history", params: [
          "p_entity_type": entityType.rawValue,
          "p_entity_id": entityId.uuidString,
          "p_limit": String(limit)
        ])
        .execute()
        .value

      #if DEBUG
      debugLog.log(
        "[AUDIT] RPC get_entity_history returned: count=\(dtos.count)",
        category: .sync
      )
      if dtos.isEmpty {
        debugLog.log("[AUDIT] WARNING: Empty result from get_entity_history", category: .sync)
      } else {
        for (index, dto) in dtos.prefix(3).enumerated() {
          debugLog.log(
            "[AUDIT]   [\(index)] action=\(dto.action), changedAt=\(dto.changedAt), tableName=\(dto.tableName)",
            category: .sync
          )
        }
        if dtos.count > 3 {
          debugLog.log("[AUDIT]   ... and \(dtos.count - 3) more entries", category: .sync)
        }
      }
      #endif

      return dtos.map { $0.toModel() }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] RPC get_entity_history FAILED", error: error)
      #endif
      throw error
    }
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

    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchRecentlyDeleted called: entityType=\(entityType?.rawValue ?? "nil"), limit=\(limit)",
      category: .sync
    )
    #endif

    do {
      let dtos: [AuditEntryDTO] = try await supabase
        .rpc("get_recently_deleted", params: params)
        .execute()
        .value

      #if DEBUG
      debugLog.log(
        "[AUDIT] RPC get_recently_deleted returned: count=\(dtos.count)",
        category: .sync
      )
      if dtos.isEmpty {
        debugLog.log("[AUDIT] WARNING: Empty result from get_recently_deleted", category: .sync)
      } else {
        for (index, dto) in dtos.prefix(3).enumerated() {
          debugLog.log(
            "[AUDIT]   [\(index)] action=\(dto.action), entityType=\(dto.tableName), recordPk=\(dto.recordPk)",
            category: .sync
          )
        }
        if dtos.count > 3 {
          debugLog.log("[AUDIT]   ... and \(dtos.count - 3) more entries", category: .sync)
        }
      }
      #endif

      return dtos.map { $0.toModel() }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] RPC get_recently_deleted FAILED", error: error)
      #endif
      throw error
    }
  }

  // MARK: - Fetch Assignee History (via RPC)

  /// Fetch assignment history for a task via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type='task_assignee', p_entity_id, p_limit)`
  func fetchTaskAssigneeHistory(taskId: UUID, limit: Int = 50) async throws -> [AuditEntry] {
    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchTaskAssigneeHistory called: taskId=\(taskId), limit=\(limit)",
      category: .sync
    )
    #endif

    do {
      let dtos: [AuditEntryDTO] = try await supabase
        .rpc("get_entity_history", params: [
          "p_entity_type": AuditableEntity.taskAssignee.rawValue,
          "p_entity_id": taskId.uuidString,
          "p_limit": String(limit)
        ])
        .execute()
        .value

      #if DEBUG
      debugLog.log(
        "[AUDIT] fetchTaskAssigneeHistory returned: count=\(dtos.count)",
        category: .sync
      )
      #endif

      return dtos.map { $0.toModel() }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] fetchTaskAssigneeHistory FAILED", error: error)
      #endif
      throw error
    }
  }

  /// Fetch assignment history for an activity via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type='activity_assignee', p_entity_id, p_limit)`
  func fetchActivityAssigneeHistory(activityId: UUID, limit: Int = 50) async throws -> [AuditEntry] {
    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchActivityAssigneeHistory called: activityId=\(activityId), limit=\(limit)",
      category: .sync
    )
    #endif

    do {
      let dtos: [AuditEntryDTO] = try await supabase
        .rpc("get_entity_history", params: [
          "p_entity_type": AuditableEntity.activityAssignee.rawValue,
          "p_entity_id": activityId.uuidString,
          "p_limit": String(limit)
        ])
        .execute()
        .value

      #if DEBUG
      debugLog.log(
        "[AUDIT] fetchActivityAssigneeHistory returned: count=\(dtos.count)",
        category: .sync
      )
      #endif

      return dtos.map { $0.toModel() }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] fetchActivityAssigneeHistory FAILED", error: error)
      #endif
      throw error
    }
  }

  // MARK: - Fetch Related History (Notes)

  /// Fetch note history for a parent entity via public RPC
  ///
  /// Calls: `get_entity_history(p_entity_type='note', p_entity_id, p_limit)`
  /// Note: The RPC filters by parent_id in the old_row/new_row JSONB
  func fetchNotesHistory(parentType _: AuditableEntity, parentId: UUID, limit: Int = 50)
    async throws -> [AuditEntry]
  {
    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchNotesHistory called: parentId=\(parentId), limit=\(limit)",
      category: .sync
    )
    #endif

    do {
      let dtos: [AuditEntryDTO] = try await supabase
        .rpc("get_entity_history", params: [
          "p_entity_type": AuditableEntity.note.rawValue,
          "p_entity_id": parentId.uuidString,
          "p_limit": String(limit)
        ])
        .execute()
        .value

      #if DEBUG
      debugLog.log(
        "[AUDIT] fetchNotesHistory returned: count=\(dtos.count)",
        category: .sync
      )
      #endif

      return dtos.map { $0.toModel() }
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] fetchNotesHistory FAILED", error: error)
      #endif
      throw error
    }
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
    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchCombinedHistory called: entityType=\(entityType.rawValue), entityId=\(entityId), limit=\(limit)",
      category: .sync
    )
    #endif

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

    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchCombinedHistory results: primary=\(primaryHistory.count), related=\(relatedHistory.count)",
      category: .sync
    )
    #endif

    // Merge and sort by changedAt descending
    let combined = (primaryHistory + relatedHistory).sorted { $0.changedAt > $1.changedAt }

    #if DEBUG
    debugLog.log(
      "[AUDIT] fetchCombinedHistory complete: combined=\(combined.count) entries",
      category: .sync
    )
    #endif

    // Apply limit to combined result
    return Array(combined.prefix(limit))
  }

  // MARK: - Restore Entity (via RPC)

  /// Restore a deleted entity via unified RPC
  ///
  /// Calls: `restore_entity(p_entity_type, p_entity_id)`
  /// Returns: The restored entity's ID
  func restoreEntity(_ entityType: AuditableEntity, entityId: UUID) async throws -> UUID {
    #if DEBUG
    debugLog.log(
      "[AUDIT] restoreEntity called: entityType=\(entityType.rawValue), entityId=\(entityId)",
      category: .sync
    )
    #endif

    do {
      let restoredId: UUID = try await supabase
        .rpc("restore_entity", params: [
          "p_entity_type": entityType.rawValue,
          "p_entity_id": entityId.uuidString
        ])
        .execute()
        .value

      #if DEBUG
      debugLog.log(
        "[AUDIT] restoreEntity SUCCESS: restoredId=\(restoredId)",
        category: .sync
      )
      #endif

      return restoredId
    } catch let error as PostgrestError {
      #if DEBUG
      debugLog.error("[AUDIT] restoreEntity FAILED (PostgrestError)", error: error)
      #endif
      throw RestoreError.from(error)
    } catch {
      #if DEBUG
      debugLog.error("[AUDIT] restoreEntity FAILED (other error)", error: error)
      #endif
      throw error
    }
  }

  // MARK: Private

  private let supabase: SupabaseClient

}
