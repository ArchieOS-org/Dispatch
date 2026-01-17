//
//  ActivityDTO+FromModel.swift
//  Dispatch
//
//  Created for Phase 1.3: SyncManager Service
//

import Foundation

extension ActivityDTO {
  /// Initialize from SwiftData model for syncUp operations
  init(from model: Activity) {
    id = model.id
    title = model.title
    description = model.activityDescription.isEmpty ? nil : model.activityDescription
    dueDate = model.dueDate
    status = model.status.rawValue
    declaredBy = model.declaredBy
    listing = model.listingId
    createdVia = model.createdVia.rawValue
    sourceSlackMessages = model.sourceSlackMessages
    audiences = model.audiencesRaw
    // Convert TimeInterval (seconds) back to minutes for Supabase
    durationMinutes = model.duration.map { Int($0 / 60) }
    completedAt = model.completedAt
    deletedAt = model.deletedAt
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }
}
