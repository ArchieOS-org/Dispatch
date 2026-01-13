//
//  TaskAssigneeDTO+FromModel.swift
//  Dispatch
//
//  Extension for creating TaskAssigneeDTO from SwiftData model
//

import Foundation

extension TaskAssigneeDTO {
  /// Initialize from SwiftData model for syncUp operations
  init(from model: TaskAssignee) {
    id = model.id
    taskId = model.taskId
    userId = model.userId
    assignedBy = model.assignedBy
    assignedAt = model.assignedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }
}
