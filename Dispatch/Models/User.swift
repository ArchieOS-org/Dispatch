//
//  User.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var avatar: Data?
    var userType: UserType

    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    var syncedAt: Date?

    // Relationships (for realtors)
    @Relationship(deleteRule: .nullify, inverse: \Listing.owner)
    var listings: [Listing] = []

    // Relationships (for staff)
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.claimedByUser)
    var claimedTasks: [TaskItem] = []

    @Relationship(deleteRule: .nullify, inverse: \Activity.claimedByUser)
    var claimedActivities: [Activity] = []

    @Relationship(deleteRule: .nullify, inverse: \Listing.assignedStaffUser)
    var assignedListings: [Listing] = []

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        avatar: Data? = nil,
        userType: UserType,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatar = avatar
        self.userType = userType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - RealtimeSyncable Conformance
// NOTE: Users sync DOWN only (RLS prevents non-self updates)
extension User: RealtimeSyncable {
    var isDirty: Bool {
        guard let syncedAt = syncedAt else { return true }
        return updatedAt > syncedAt
    }
    // conflictResolution uses default from protocol extension (.lastWriteWins)
}
