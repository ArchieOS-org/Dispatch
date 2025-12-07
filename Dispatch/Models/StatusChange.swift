//
//  StatusChange.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class StatusChange {
    @Attribute(.unique) var id: UUID
    var parentType: ParentType
    var parentId: UUID
    var oldStatus: String?
    var newStatus: String
    var changedBy: UUID
    var changedAt: Date
    var reason: String?
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        parentType: ParentType,
        parentId: UUID,
        oldStatus: String? = nil,
        newStatus: String,
        changedBy: UUID,
        changedAt: Date = Date(),
        reason: String? = nil
    ) {
        self.id = id
        self.parentType = parentType
        self.parentId = parentId
        self.oldStatus = oldStatus
        self.newStatus = newStatus
        self.changedBy = changedBy
        self.changedAt = changedAt
        self.reason = reason
    }
}
