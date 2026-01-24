//
//  TaskSyncHandler.swift
//  Dispatch
//
//  Handles all TaskItem and TaskAssignee sync operations.
//  Extracted from EntitySyncHandler for maintainability.
//

import Foundation
import Supabase
import SwiftData

// MARK: - TaskSyncHandler

/// Handles TaskItem and TaskAssignee entity sync operations.
@MainActor
final class TaskSyncHandler: EntitySyncHandlerProtocol {

  // MARK: Lifecycle

  init(dependencies: SyncHandlerDependencies) {
    self.dependencies = dependencies
  }

  // MARK: Internal

  let dependencies: SyncHandlerDependencies

  // MARK: - SyncDown Tasks

  func syncDown(context: ModelContext, since: String) async throws {
    try await syncDownTasks(context: context, since: since, establishListingRelationship: nil)
  }

  func syncDownTasks(
    context: ModelContext,
    since: String,
    establishListingRelationship: ((TaskItem, UUID?, ModelContext) throws -> Void)?
  ) async throws {
    debugLog.log("syncDownTasks() - querying Supabase...", category: .sync)
    let dtos: [TaskDTO] = try await supabase
      .from("tasks")
      .select()
      .gte("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "tasks", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting task \(index + 1)/\(dtos.count): \(dto.id) - \(dto.title)", category: .sync)
      try upsertTask(dto: dto, context: context, establishListingRelationship: establishListingRelationship)
    }
  }

  // MARK: - SyncUp Tasks

  /// Syncs tasks using UPSERT to avoid triggering CASCADE DELETE on foreign keys.
  ///
  /// Previously used DELETE + INSERT for audit logging, but this caused CASCADE DELETE
  /// on task_assignees FK constraint, wiping out assignees when syncing tasks.
  /// UPSERT performs INSERT or UPDATE without DELETE, preserving related records.
  ///
  /// **Audit Note**: UPSERT triggers UPDATE events for existing rows. The audit system
  /// handles UPDATE events correctly via database triggers.
  func syncUp(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<TaskItem>()
    let allTasks = try context.fetch(descriptor)
    debugLog.log("syncUpTasks() - fetched \(allTasks.count) total tasks from SwiftData", category: .sync)

    // Filter for pending or failed (retry) tasks
    let pendingTasks = allTasks.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "tasks",
      count: pendingTasks.count,
      details: "of \(allTasks.count) total"
    )

    guard !pendingTasks.isEmpty else {
      debugLog.log("  No pending tasks to sync", category: .sync)
      return
    }

    debugLog.log("  Local pending: \(pendingTasks.count)", category: .sync)

    // Mark as in-flight before sync to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markTasksInFlight(Set(pendingTasks.map { $0.id }))
    defer { dependencies.conflictResolver.clearTasksInFlight() } // Always clear, even on error

    // Process each task with UPSERT (INSERT or UPDATE, no DELETE)
    for task in pendingTasks {
      let dto = TaskDTO(from: task)

      do {
        // UPSERT: Insert if new, update if exists - no CASCADE DELETE triggered
        // Discard result to prevent type inference causing decode errors
        _ = try await supabase
          .from("tasks")
          .upsert(dto)
          .execute()
        task.markSynced()
        debugLog.log("    Upserted task \(task.id) - \(task.title)", category: .sync)
      } catch {
        let message = dependencies.userFacingMessage(for: error)
        task.markFailed(message)
        debugLog.error("    Task \(task.id) sync failed: \(message)")
      }
    }

    debugLog.log("syncUpTasks() complete", category: .sync)
  }

  // MARK: - Upsert Task

  /// Upsert a task from remote DTO. Relationship establishment delegated to coordinator.
  func upsertTask(
    dto: TaskDTO,
    context: ModelContext,
    establishListingRelationship: ((TaskItem, UUID?, ModelContext) throws -> Void)? = nil
  ) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<TaskItem>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip ALL updates if local-authoritative
      if
        dependencies.conflictResolver.isLocalAuthoritative(
          existing,
          inFlight: dependencies.conflictResolver.isTaskInFlight(existing.id)
        )
      {
        debugLog.log(
          "[SyncDown] Skip update for task \(dto.id) - local-authoritative (state=\(existing.syncState))",
          category: .sync
        )
        return
      }

      debugLog.log("    UPDATE existing task: \(dto.id)", category: .sync)
      // Apply server state ONLY when not local-authoritative
      existing.title = dto.title
      existing.taskDescription = dto.description ?? ""
      existing.dueDate = dto.dueDate
      existing.status = TaskStatus(rawValue: dto.status) ?? .open
      existing.completedAt = dto.completedAt
      existing.deletedAt = dto.deletedAt
      existing.updatedAt = dto.updatedAt
      existing.listingId = dto.listing
      if let establishListing = establishListingRelationship {
        try establishListing(existing, dto.listing, context)
      }
      existing.markSynced()
    } else {
      debugLog.log("    INSERT new task: \(dto.id)", category: .sync)
      let newTask = dto.toModel()
      newTask.markSynced()
      context.insert(newTask)
      if let establishListing = establishListingRelationship {
        try establishListing(newTask, dto.listing, context)
      }
    }
  }

  // MARK: - Reconcile Missing Tasks

  /// Reconciles missing tasks - finds tasks on server that don't exist locally and fetches them.
  /// This is a failsafe to catch tasks that were missed due to watermark issues or other sync gaps.
  /// Runs on every sync to ensure data consistency.
  func reconcileMissingTasks(context: ModelContext) async throws -> Int {
    // 1. Fetch all task IDs from server (lightweight query)
    let remoteDTOs: [IDOnlyDTO] = try await supabase
      .from("tasks")
      .select("id")
      .execute()
      .value
    let remoteIds = Set(remoteDTOs.map { $0.id })
    debugLog.log("  Remote tasks: \(remoteIds.count)", category: .sync)

    // 2. Get all local task IDs
    let localDescriptor = FetchDescriptor<TaskItem>()
    let localTasks = try context.fetch(localDescriptor)
    let localIds = Set(localTasks.map { $0.id })
    debugLog.log("  Local tasks: \(localIds.count)", category: .sync)

    // 3. Find IDs that exist on server but not locally
    let missingIds = remoteIds.subtracting(localIds)

    guard !missingIds.isEmpty else {
      debugLog.log("  No missing tasks", category: .sync)
      return 0
    }

    debugLog.log("  Warning: Found \(missingIds.count) missing tasks, fetching...", category: .sync)

    // 4. Fetch full task data for missing IDs (batch query)
    let missingDTOs: [TaskDTO] = try await supabase
      .from("tasks")
      .select()
      .in("id", values: Array(missingIds).map { $0.uuidString })
      .execute()
      .value

    // 5. Upsert missing tasks
    for dto in missingDTOs {
      try upsertTask(dto: dto, context: context, establishListingRelationship: nil)
    }

    debugLog.log("  Reconciled \(missingDTOs.count) missing tasks", category: .sync)
    return missingDTOs.count
  }

  // MARK: - Delete Task

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

  // MARK: - SyncDown TaskAssignees

  func syncDownTaskAssignees(
    context: ModelContext,
    since: String,
    establishTaskRelationship: ((TaskAssignee, UUID, ModelContext) throws -> Void)?
  ) async throws {
    debugLog.log("syncDownTaskAssignees() - querying Supabase...", category: .sync)
    let dtos: [TaskAssigneeDTO] = try await supabase
      .from("task_assignees")
      .select()
      .gte("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "task_assignees", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting task assignee \(index + 1)/\(dtos.count): \(dto.id)", category: .sync)
      try upsertTaskAssignee(dto: dto, context: context, establishTaskRelationship: establishTaskRelationship)
    }
  }

  // MARK: - SyncUp TaskAssignees

  /// Syncs task assignees using UPSERT with local deduplication.
  ///
  /// **Problem Solved**: Multiple local assignees can exist for the same (task_id, user_id) composite key,
  /// causing duplicate sync operations and inconsistent state.
  ///
  /// **Solution**:
  /// 1. Deduplicate locally first - group by (task_id, user_id), keep newest (by updatedAt), delete rest
  /// 2. Use UPSERT with `onConflict: "task_id,user_id"` for efficient single-operation sync
  /// 3. Process each composite key exactly once
  ///
  /// **Audit Note**: UPSERT triggers INSERT for new records and UPDATE for existing records.
  /// The audit system captures all these events via database triggers.
  ///
  /// **IMPORTANT**: This method only syncs the CURRENT USER's assignee records.
  /// RLS policies only allow users to INSERT their own assignee records (or others'
  /// if they are task creator/listing owner). To avoid permission errors, each user
  /// manages their own claim/unclaim independently.
  ///
  /// - Parameter taskIdsToSync: Pre-captured task IDs to sync assignees for. If nil, falls back to checking
  ///   current pending tasks (legacy behavior). This parameter is critical because task sync marks tasks as
  ///   synced BEFORE assignee sync runs, so we must capture pending IDs at the start of the sync cycle.
  func syncUpTaskAssignees(context: ModelContext, taskIdsToSync: Set<UUID>? = nil) async throws {
    // Get current user ID - required for filtering assignees
    guard let currentUserId = dependencies.getCurrentUserID() else {
      debugLog.log("syncUpTaskAssignees() - no current user, skipping", category: .sync)
      return
    }

    // Use pre-captured IDs if provided, otherwise fall back to current pending tasks
    let pendingTaskIds: [UUID]
    if let preCapturedIds = taskIdsToSync {
      pendingTaskIds = Array(preCapturedIds)
      debugLog.log(
        "syncUpTaskAssignees() - using \(pendingTaskIds.count) pre-captured task IDs",
        category: .sync
      )
    } else {
      // Legacy fallback: Find tasks that have pending changes (their assignees may have changed)
      let taskDescriptor = FetchDescriptor<TaskItem>()
      let allTasks = try context.fetch(taskDescriptor)
      let pendingTasks = allTasks.filter { $0.syncState == .pending || $0.syncState == .failed }
      pendingTaskIds = pendingTasks.map { $0.id }
    }

    guard !pendingTaskIds.isEmpty else {
      debugLog.log("syncUpTaskAssignees() - no tasks to process, skipping", category: .sync)
      return
    }
    debugLog.log(
      "syncUpTaskAssignees() - processing assignees for \(pendingTaskIds.count) pending tasks (user: \(currentUserId))",
      category: .sync
    )

    // Get current local assignees for pending tasks - ONLY for current user
    let assigneeDescriptor = FetchDescriptor<TaskAssignee>()
    let allLocalAssignees = try context.fetch(assigneeDescriptor)
    let localAssigneesForPending = allLocalAssignees.filter {
      pendingTaskIds.contains($0.taskId) && $0.userId == currentUserId
    }

    // =========================================================================
    // STEP 1: Local Deduplication
    // Group by composite key (task_id, user_id), keep newest by updatedAt, delete rest
    // =========================================================================
    var assigneesByCompositeKey: [String: [TaskAssignee]] = [:]
    for assignee in localAssigneesForPending {
      let compositeKey = "\(assignee.taskId)-\(assignee.userId)"
      assigneesByCompositeKey[compositeKey, default: []].append(assignee)
    }

    // Deduplicate: keep newest, delete duplicates
    var dedupedAssignees: [String: TaskAssignee] = [:]
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
    var localAssigneesById: [UUID: TaskAssignee] = [:]
    for assignee in dedupedAssignees.values {
      localAssigneesById[assignee.id] = assignee
    }

    // Fetch server-side assignees for these tasks - ONLY current user's records
    let serverAssignees: [TaskAssigneeDTO] = try await supabase
      .from("task_assignees")
      .select()
      .in("task_id", values: pendingTaskIds.map { $0.uuidString })
      .eq("user_id", value: currentUserId.uuidString)
      .execute()
      .value

    // Build a set of (task_id, user_id) composite keys that exist on server
    var serverCompositeKeys: Set<String> = []
    for dto in serverAssignees {
      serverCompositeKeys.insert("\(dto.taskId)-\(dto.userId)")
    }

    debugLog.log(
      "  Local assignees (after dedup): \(dedupedAssignees.count), Server assignees (current user): \(serverAssignees.count)",
      category: .sync
    )

    // Mark local assignees as in-flight to prevent realtime echo
    dependencies.conflictResolver.markTaskAssigneesInFlight(Set(localAssigneesById.keys))
    defer { dependencies.conflictResolver.clearTaskAssigneesInFlight() }

    // =========================================================================
    // STEP 2: Compute desired state per task
    // Local composite keys = what should exist, Server keys - Local keys = what to delete
    // =========================================================================
    let localCompositeKeys = Set(dedupedAssignees.keys)

    // Process each pending task
    for taskId in pendingTaskIds {
      // Find server keys for this task that are NOT in local (user unclaimed)
      let serverKeysForTask = serverCompositeKeys.filter { $0.hasPrefix("\(taskId)-") }
      let localKeysForTask = localCompositeKeys.filter { $0.hasPrefix("\(taskId)-") }
      let toDeleteKeys = serverKeysForTask.subtracting(localKeysForTask)

      // DELETE: Current user's assignee on server but not local (user unclaimed)
      if !toDeleteKeys.isEmpty {
        debugLog.log(
          "  Task \(taskId): deleting \(toDeleteKeys.count) removed assignees (current user)",
          category: .sync
        )
        for compositeKey in toDeleteKeys {
          // Parse the composite key to get task_id and user_id
          let parts = compositeKey.split(separator: "-")
          guard
            parts.count == 2,
            let deleteTaskId = UUID(uuidString: String(parts[0])),
            let deleteUserId = UUID(uuidString: String(parts[1]))
          else {
            debugLog.error("    Invalid composite key format: \(compositeKey)")
            continue
          }
          do {
            try await supabase
              .from("task_assignees")
              .delete()
              .eq("task_id", value: deleteTaskId.uuidString)
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
      for compositeKey in localKeysForTask {
        guard let assignee = dedupedAssignees[compositeKey] else { continue }
        let dto = TaskAssigneeDTO(model: assignee)

        do {
          // UPSERT with onConflict ensures single operation:
          // - INSERT if (task_id, user_id) doesn't exist
          // - UPDATE if (task_id, user_id) already exists
          _ = try await supabase
            .from("task_assignees")
            .upsert(dto, onConflict: "task_id,user_id")
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

    debugLog.log("syncUpTaskAssignees() complete", category: .sync)
  }

  // MARK: - Upsert TaskAssignee

  /// Upsert a task assignee from remote DTO. Relationship establishment delegated to coordinator.
  func upsertTaskAssignee(
    dto: TaskAssigneeDTO,
    context: ModelContext,
    establishTaskRelationship: ((TaskAssignee, UUID, ModelContext) throws -> Void)? = nil
  ) throws {
    let targetId = dto.id
    let descriptor = FetchDescriptor<TaskAssignee>(
      predicate: #Predicate { $0.id == targetId }
    )

    if let existing = try context.fetch(descriptor).first {
      // Local-first: skip ALL updates if local-authoritative
      if
        dependencies.conflictResolver.isLocalAuthoritative(
          existing,
          inFlight: dependencies.conflictResolver.isTaskAssigneeInFlight(existing.id)
        )
      {
        debugLog.log(
          "[SyncDown] Skip update for task assignee \(dto.id) - local-authoritative (state=\(existing.syncState))",
          category: .sync
        )
        return
      }

      debugLog.log("    UPDATE existing task assignee: \(dto.id)", category: .sync)
      existing.taskId = dto.taskId
      existing.userId = dto.userId
      existing.assignedBy = dto.assignedBy
      existing.assignedAt = dto.assignedAt
      existing.updatedAt = dto.updatedAt
      existing.markSynced()

      // Establish relationship with parent task
      if let establishTask = establishTaskRelationship {
        try establishTask(existing, dto.taskId, context)
      }
    } else {
      debugLog.log("    INSERT new task assignee: \(dto.id)", category: .sync)
      let newAssignee = dto.toModel()
      newAssignee.markSynced()
      context.insert(newAssignee)
      if let establishTask = establishTaskRelationship {
        try establishTask(newAssignee, dto.taskId, context)
      }
    }
  }

  // MARK: Private

  /// Lightweight DTO for fetching only IDs from Supabase
  private struct IDOnlyDTO: Codable {
    let id: UUID
  }
}
