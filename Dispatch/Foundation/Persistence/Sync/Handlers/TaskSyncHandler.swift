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

    // Mark as in-flight before upsert to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markTasksInFlight(Set(pendingTasks.map { $0.id }))
    defer { dependencies.conflictResolver.clearTasksInFlight() } // Always clear, even on error

    // Try batch first for efficiency
    do {
      let dtos = pendingTasks.map { TaskDTO(from: $0) }
      debugLog.log("  Batch upserting \(dtos.count) tasks to Supabase...", category: .sync)
      try await supabase
        .from("tasks")
        .upsert(dtos)
        .execute()
      debugLog.log("  Batch upsert successful", category: .sync)

      // Success - mark all synced
      for task in pendingTasks {
        task.markSynced()
      }
      debugLog.log("  Marked \(pendingTasks.count) tasks as synced", category: .sync)
    } catch {
      // Batch failed - try individual items to isolate failures
      debugLog.log("Batch task sync failed, trying individually: \(error.localizedDescription)", category: .error)

      for task in pendingTasks {
        do {
          let dto = TaskDTO(from: task)
          try await supabase
            .from("tasks")
            .upsert([dto])
            .execute()
          task.markSynced()
          debugLog.log("  Task \(task.id) synced individually", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          task.markFailed(message)
          debugLog.error("  Task \(task.id) sync failed: \(message)")
        }
      }
    }
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

  func syncUpTaskAssignees(context: ModelContext) async throws {
    let descriptor = FetchDescriptor<TaskAssignee>()
    let allAssignees = try context.fetch(descriptor)
    debugLog.log("syncUpTaskAssignees() - fetched \(allAssignees.count) total task assignees from SwiftData", category: .sync)

    let pendingAssignees = allAssignees.filter { $0.syncState == .pending || $0.syncState == .failed }
    debugLog.logSyncOperation(
      operation: "PENDING",
      table: "task_assignees",
      count: pendingAssignees.count,
      details: "of \(allAssignees.count) total"
    )

    guard !pendingAssignees.isEmpty else {
      debugLog.log("  No pending task assignees to sync", category: .sync)
      return
    }

    // Mark as in-flight before upsert to prevent realtime echo from overwriting local state
    dependencies.conflictResolver.markTaskAssigneesInFlight(Set(pendingAssignees.map { $0.id }))
    defer { dependencies.conflictResolver.clearTaskAssigneesInFlight() } // Always clear, even on error

    // Try batch first for efficiency
    do {
      let dtos = pendingAssignees.map { TaskAssigneeDTO(model: $0) }
      debugLog.log("  Batch upserting \(dtos.count) task assignees to Supabase...", category: .sync)
      try await supabase
        .from("task_assignees")
        .upsert(dtos)
        .execute()
      debugLog.log("  Batch upsert successful", category: .sync)

      for assignee in pendingAssignees {
        assignee.markSynced()
      }
      debugLog.log("  Marked \(pendingAssignees.count) task assignees as synced", category: .sync)
    } catch {
      // Batch failed - try individual items to isolate failures
      debugLog.log("Batch task assignee sync failed, trying individually: \(error.localizedDescription)", category: .error)

      for assignee in pendingAssignees {
        do {
          let dto = TaskAssigneeDTO(model: assignee)
          try await supabase
            .from("task_assignees")
            .upsert([dto])
            .execute()
          assignee.markSynced()
          debugLog.log("  TaskAssignee \(assignee.id) synced individually", category: .sync)
        } catch {
          let message = dependencies.userFacingMessage(for: error)
          assignee.markFailed(message)
          debugLog.error("  TaskAssignee \(assignee.id) sync failed: \(message)")
        }
      }
    }
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
}
