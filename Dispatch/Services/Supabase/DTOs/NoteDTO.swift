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

    enum CodingKeys: String, CodingKey {
        case id, content
        case createdBy = "created_by"
        case parentType = "parent_type"
        case parentId = "parent_id"
        case editedAt = "edited_at"
        case editedBy = "edited_by"
        case createdAt = "created_at"
    }

    func toModel() -> Note {
        let note = Note(
            id: id,
            content: content,
            createdBy: createdBy,
            parentType: ParentType(rawValue: parentType) ?? .task,
            parentId: parentId,
            createdAt: createdAt
        )
        note.editedAt = editedAt
        note.editedBy = editedBy
        return note
    }
}
