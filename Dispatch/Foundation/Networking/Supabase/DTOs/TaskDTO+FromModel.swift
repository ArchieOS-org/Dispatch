//
//  TaskDTO+FromModel.swift
//  Dispatch
//
//  Created for Phase 1.3: SyncManager Service
//

import Foundation

extension TaskDTO {
  /// Initialize from SwiftData model for syncUp operations
  init(from model: TaskItem) {
    id = model.id
    title = model.title
    description = model.taskDescription.isEmpty ? nil : model.taskDescription
    dueDate = model.dueDate
    status = model.status.rawValue
    declaredBy = model.declaredBy
    listing = model.listingId
    createdVia = model.createdVia.rawValue
    sourceSlackMessages = model.sourceSlackMessages
    audiences = model.audiencesRaw
    completedAt = model.completedAt
    deletedAt = model.deletedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }
}
