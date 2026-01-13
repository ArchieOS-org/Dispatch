//
//  ActivityAssigneeDTO+FromModel.swift
//  Dispatch
//
//  Extension for creating ActivityAssigneeDTO from SwiftData model
//

import Foundation

extension ActivityAssigneeDTO {
  /// Initialize from SwiftData model for syncUp operations
  init(from model: ActivityAssignee) {
    id = model.id
    activityId = model.activityId
    userId = model.userId
    assignedBy = model.assignedBy
    assignedAt = model.assignedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }
}
