//
//  ActivityAssigneeDTO.swift
//  Dispatch
//
//  DTO for syncing activity_assignees table with Supabase.
//

import Foundation

struct ActivityAssigneeDTO: Codable, Sendable {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    activityId: UUID,
    userId: UUID,
    assignedBy: UUID,
    assignedAt: Date = Date(),
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.activityId = activityId
    self.userId = userId
    self.assignedBy = assignedBy
    self.assignedAt = assignedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(model: ActivityAssignee) {
    id = model.id
    activityId = model.activityId
    userId = model.userId
    assignedBy = model.assignedBy
    assignedAt = model.assignedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case activityId = "activity_id"
    case userId = "user_id"
    case assignedBy = "assigned_by"
    case assignedAt = "assigned_at"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let activityId: UUID
  let userId: UUID
  let assignedBy: UUID
  let assignedAt: Date
  let createdAt: Date
  let updatedAt: Date

  func toModel() -> ActivityAssignee {
    ActivityAssignee(
      id: id,
      activityId: activityId,
      userId: userId,
      assignedBy: assignedBy,
      assignedAt: assignedAt,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

}
