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
      .gt("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "tasks", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting task \(index + 1)/\(dtos.count): \(dto.id) - \(dto.title)", category: .sync)
      try upsertTask(dto: dto, context: context, establishListingRelationship: establishListingRelationship)
    }
  }

  // MARK: - SyncUp Tasks

  /// Syncs tasks using explicit DELETE + INSERT to ensure proper audit logging.
  ///
  /// The audit system only captures INSERT and DELETE events, not UPDATE events.
  /// Using UPSERT would trigger UPDATE when modifying an existing task, which wouldn't
  /// appear in the audit history. This method ensures:
  /// - Task modifications generate DELETE + INSERT audit events
  /// - Soft-deleted tasks are synced with their deletedAt value preserved
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

    // Fetch server-side state for pending tasks to know which ones exist
    let pendingTaskIds = pendingTasks.map { $0.id }
    let serverTasks: [TaskDTO] = try await supabase
      .from("tasks")
      .select("id")
      .in("id", values: pendingTaskIds.map { $0.uuidString })
      .execute()
      .value
    let serverTaskIds = Set(serverTasks.map { $0.id })

    debugLog.log(
      "  Local pending: \(pendingTasks.count), Exist on server: \(serverTaskIds.count)",
      category: .sync
    )

    // Mark as in-flight before sync to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markTasksInFlight(Set(pendingTasks.map { $0.id }))
    defer { dependencies.conflictResolver.clearTasksInFlight() } // Always clear, even on error

    // Process each task with DELETE + INSERT pattern
    for task in pendingTasks {
      let dto = TaskDTO(from: task)

      do {
        // Delete if exists on server (ensures audit trigger fires for the change)
        if serverTaskIds.contains(task.id) {
          try await supabase
            .from("tasks")
            .delete()
            .eq("id", value: task.id.uuidString)
            .execute()
          debugLog.log("    Deleted existing task \(task.id) for re-insert", category: .sync)
        }

        // Insert the task (generates INSERT audit event)
        try await supabase
          .from("tasks")
          .insert(dto)
          .execute()
        task.markSynced()
        debugLog.log("    Inserted task \(task.id) - \(task.title)", category: .sync)
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
      .gt("updated_at", value: since)
      .execute()
      .value

    debugLog.logSyncOperation(operation: "FETCH", table: "task_assignees", count: dtos.count)

    for (index, dto) in dtos.enumerated() {
      debugLog.log("  Upserting task assignee \(index + 1)/\(dtos.count): \(dto.id)", category: .sync)
      try upsertTaskAssignee(dto: dto, context: context, establishTaskRelationship: establishTaskRelationship)
    }
  }

  // MARK: - SyncUp TaskAssignees

  /// Syncs task assignees using explicit DELETE + INSERT to ensure proper audit logging.
  ///
  /// The audit system only captures INSERT and DELETE events, not UPDATE events.
  /// Using UPSERT would trigger UPDATE when re-claiming a task, which wouldn't
  /// appear in the audit history. This method ensures:
  /// - Unclaiming generates a DELETE audit event
  /// - Claiming (including re-claiming) generates an INSERT audit event
  ///
  /// - Parameter taskIdsToSync: Pre-captured task IDs to sync assignees for. If nil, falls back to checking
  ///   current pending tasks (legacy behavior). This parameter is critical because task sync marks tasks as
  ///   synced BEFORE assignee sync runs, so we must capture pending IDs at the start of the sync cycle.
  func syncUpTaskAssignees(context: ModelContext, taskIdsToSync: Set<UUID>? = nil) async throws {
    // Use pre-captured IDs if provided, otherwise fall back to current pending tasks
    let pendingTaskIds: [UUID]
    if let preCaputredIds = taskIdsToSync {
      pendingTaskIds = Array(preCaputredIds)
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
      "syncUpTaskAssignees() - processing assignees for \(pendingTaskIds.count) pending tasks",
      category: .sync
    )

    // Get current local assignees for pending tasks
    let assigneeDescriptor = FetchDescriptor<TaskAssignee>()
    let allLocalAssignees = try context.fetch(assigneeDescriptor)
    let localAssigneesForPending = allLocalAssignees.filter { pendingTaskIds.contains($0.taskId) }

    // Build a map of task ID -> local assignee IDs
    var localAssigneesByTask: [UUID: Set<UUID>] = [:]
    var localAssigneesById: [UUID: TaskAssignee] = [:]
    for assignee in localAssigneesForPending {
      localAssigneesByTask[assignee.taskId, default: []].insert(assignee.id)
      localAssigneesById[assignee.id] = assignee
    }

    // Fetch server-side assignees for these tasks
    let serverAssignees: [TaskAssigneeDTO] = try await supabase
      .from("task_assignees")
      .select()
      .in("task_id", values: pendingTaskIds.map { $0.uuidString })
      .execute()
      .value

    // Build a map of task ID -> server assignee IDs
    var serverAssigneesByTask: [UUID: Set<UUID>] = [:]
    for dto in serverAssignees {
      serverAssigneesByTask[dto.taskId, default: []].insert(dto.id)
    }

    debugLog.log(
      "  Local assignees: \(localAssigneesForPending.count), Server assignees: \(serverAssignees.count)",
      category: .sync
    )

    // Mark local assignees as in-flight to prevent realtime echo
    dependencies.conflictResolver.markTaskAssigneesInFlight(Set(localAssigneesById.keys))
    defer { dependencies.conflictResolver.clearTaskAssigneesInFlight() }

    // Process each pending task
    for taskId in pendingTaskIds {
      let localIds = localAssigneesByTask[taskId] ?? []
      let serverIds = serverAssigneesByTask[taskId] ?? []

      // 1. DELETE: Assignees on server but not local (user unclaimed)
      let toDelete = serverIds.subtracting(localIds)
      if !toDelete.isEmpty {
        debugLog.log("  Task \(taskId): deleting \(toDelete.count) removed assignees", category: .sync)
        for assigneeId in toDelete {
          do {
            try await supabase
              .from("task_assignees")
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
        let dto = TaskAssigneeDTO(model: assignee)

        do {
          // Delete if exists on server (handles re-claim case)
          if serverIds.contains(assigneeId) {
            try await supabase
              .from("task_assignees")
              .delete()
              .eq("id", value: assigneeId.uuidString)
              .execute()
            debugLog.log("    Deleted existing assignee \(assigneeId) for re-insert", category: .sync)
          }

          // Insert the assignee (generates INSERT audit event)
          try await supabase
            .from("task_assignees")
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
