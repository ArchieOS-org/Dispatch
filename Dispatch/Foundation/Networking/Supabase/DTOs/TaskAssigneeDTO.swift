//
//  TaskAssigneeDTO.swift
//  Dispatch
//
//  DTO for syncing task_assignees table with Supabase.
//

import Foundation

struct TaskAssigneeDTO: Codable, Sendable {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    taskId: UUID,
    userId: UUID,
    assignedBy: UUID,
    assignedAt: Date = Date(),
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.taskId = taskId
    self.userId = userId
    self.assignedBy = assignedBy
    self.assignedAt = assignedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(model: TaskAssignee) {
    id = model.id
    taskId = model.taskId
    userId = model.userId
    assignedBy = model.assignedBy
    assignedAt = model.assignedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case taskId = "task_id"
    case userId = "user_id"
    case assignedBy = "assigned_by"
    case assignedAt = "assigned_at"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let taskId: UUID
  let userId: UUID
  let assignedBy: UUID
  let assignedAt: Date
  let createdAt: Date
  let updatedAt: Date

  func toModel() -> TaskAssignee {
    TaskAssignee(
      id: id,
      taskId: taskId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: assignedAt,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

}
