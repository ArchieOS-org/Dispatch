//
//  Activity.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class Activity: WorkItemProtocol, ClaimableProtocol, NotableProtocol {
    @Attribute(.unique) var id: UUID
    var title: String
    var activityDescription: String
    var type: ActivityType
    var dueDate: Date?
    var priority: Priority
    var status: ActivityStatus

    // Foreign keys
    var declaredBy: UUID
    var claimedBy: UUID?
    var listingId: UUID?

    // Metadata
    var createdVia: CreationSource
    var sourceSlackMessages: [String]?
    var duration: TimeInterval?

    // Timestamps
    var claimedAt: Date?
    var completedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncedAt: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var notes: [Note] = []

    @Relationship(deleteRule: .cascade)
    var subtasks: [Subtask] = []

    @Relationship(deleteRule: .cascade)
    var statusHistory: [StatusChange] = []

    @Relationship(deleteRule: .cascade)
    var claimHistory: [ClaimEvent] = []

    // Inverse relationships
    var claimedByUser: User?
    var listing: Listing?

    init(
        id: UUID = UUID(),
        title: String,
        activityDescription: String = "",
        type: ActivityType = .other,
        dueDate: Date? = nil,
        priority: Priority = .medium,
        status: ActivityStatus = .open,
        declaredBy: UUID,
        claimedBy: UUID? = nil,
        listingId: UUID? = nil,
        createdVia: CreationSource = .dispatch,
        sourceSlackMessages: [String]? = nil,
        duration: TimeInterval? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.activityDescription = activityDescription
        self.type = type
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.declaredBy = declaredBy
        self.claimedBy = claimedBy
        self.listingId = listingId
        self.createdVia = createdVia
        self.sourceSlackMessages = sourceSlackMessages
        self.duration = duration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - RealtimeSyncable Conformance
extension Activity: RealtimeSyncable {
    var isDirty: Bool {
        guard let syncedAt = syncedAt else { return true }
        return updatedAt > syncedAt
    }
    // conflictResolution uses default from protocol extension (.lastWriteWins)
}
