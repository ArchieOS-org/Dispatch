//
//  Note.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdBy: UUID
    var parentType: ParentType
    var parentId: UUID

    // Edit tracking
    var editedAt: Date?
    var editedBy: UUID?

    // Timestamps
    var createdAt: Date
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        content: String,
        createdBy: UUID,
        parentType: ParentType,
        parentId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.createdBy = createdBy
        self.parentType = parentType
        self.parentId = parentId
        self.createdAt = createdAt
    }
}
