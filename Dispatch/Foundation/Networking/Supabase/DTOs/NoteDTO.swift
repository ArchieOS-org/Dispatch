//
//  NoteDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct NoteDTO: Codable, Sendable {
    let id: UUID
    let content: String
    let createdBy: UUID
    let parentType: String
    let parentId: UUID
    let editedAt: Date?
    let editedBy: UUID?
    let createdAt: Date
    let updatedAt: Date? // Nullable for legacy data, but DB default is now()
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, content
        case createdBy = "created_by"
        case parentType = "parent_type"
        case parentId = "parent_id"
        case editedAt = "edited_at"
        case editedBy = "edited_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from model: Note) {
        self.id = model.id
        self.content = model.content
        self.createdBy = model.createdBy
        self.parentType = model.parentType.rawValue
        self.parentId = model.parentId
        self.editedAt = model.editedAt
        self.editedBy = model.editedBy
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.deletedAt = model.deletedAt
    }

    func toModel() -> Note {
        let resolvedParentType: ParentType
        if let type = ParentType(rawValue: parentType) {
            resolvedParentType = type
        } else {
            debugLog.log("⚠️ Invalid parentType '\(parentType)' for Note \(id), defaulting to .task", category: .sync)
            resolvedParentType = .task
        }

        let note = Note(
            id: id,
            content: content,
            createdBy: createdBy,
            parentType: resolvedParentType,
            parentId: parentId,
            createdAt: createdAt
        )
        note.editedAt = editedAt
        note.editedBy = editedBy
        note.updatedAt = updatedAt ?? createdAt // Fallback for old records
        note.deletedAt = deletedAt
        note.markSynced() // Mark as synced since it came from server
        return note
    }
}
