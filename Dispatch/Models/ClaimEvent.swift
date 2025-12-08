//
//  ClaimEvent.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class ClaimEvent {
    @Attribute(.unique) var id: UUID
    var parentType: ParentType
    var parentId: UUID
    var action: ClaimAction
    var userId: UUID
    var performedAt: Date
    var reason: String?
    var createdAt: Date
    var updatedAt: Date
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        parentType: ParentType,
        parentId: UUID,
        action: ClaimAction,
        userId: UUID,
        performedAt: Date = Date(),
        reason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.parentType = parentType
        self.parentId = parentId
        self.action = action
        self.userId = userId
        self.performedAt = performedAt
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - RealtimeSyncable Conformance
extension ClaimEvent: RealtimeSyncable {
    var isDirty: Bool {
        guard let syncedAt = syncedAt else { return true }
        return updatedAt > syncedAt
    }
}
