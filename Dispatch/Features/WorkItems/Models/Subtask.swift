//
//  Subtask.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class Subtask {
    @Attribute(.unique) var id: UUID
    var title: String
    var completed: Bool
    var parentType: ParentType
    var parentId: UUID

    // Timestamps
    var createdAt: Date
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        completed: Bool = false,
        parentType: ParentType,
        parentId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.completed = completed
        self.parentType = parentType
        self.parentId = parentId
        self.createdAt = createdAt
    }
}
