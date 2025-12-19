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
        self.id = model.id
        self.title = model.title
        self.description = model.activityDescription.isEmpty ? nil : model.activityDescription
        self.activityType = model.type.rawValue
        self.dueDate = model.dueDate
        self.priority = model.priority.rawValue
        self.status = model.status.rawValue
        self.declaredBy = model.declaredBy
        self.claimedBy = model.claimedBy
        self.listing = model.listingId
        self.createdVia = model.createdVia.rawValue
        self.sourceSlackMessages = model.sourceSlackMessages
        self.audiences = model.audiencesRaw
        // Convert TimeInterval (seconds) back to minutes for Supabase
        self.durationMinutes = model.duration.map { Int($0 / 60) }
        self.claimedAt = model.claimedAt
        self.completedAt = model.completedAt
        self.deletedAt = model.deletedAt
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}
