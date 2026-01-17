//
//  NoteDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct NoteDTO: Codable, Sendable {

  // MARK: Lifecycle

  init(
    id: UUID,
    content: String,
    createdBy: UUID,
    parentType: String,
    parentId: UUID,
    editedAt: Date?,
    editedBy: UUID?,
    createdAt: Date,
    updatedAt: Date?,
    deletedAt: Date?,
    deletedBy: UUID?
  ) {
    self.id = id
    self.content = content
    self.createdBy = createdBy
    self.parentType = parentType
    self.parentId = parentId
    self.editedAt = editedAt
    self.editedBy = editedBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deletedAt = deletedAt
    self.deletedBy = deletedBy
  }

  init(from model: Note) {
    id = model.id
    content = model.content
    createdBy = model.createdBy
    parentType = model.parentType.rawValue
    parentId = model.parentId
    editedAt = model.editedAt
    editedBy = model.editedBy
    createdAt = model.createdAt
    updatedAt = model.updatedAt
    deletedAt = model.deletedAt
    deletedBy = model.deletedBy
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case content
    case createdBy = "created_by"
    case parentType = "parent_type"
    case parentId = "parent_id"
    case editedAt = "edited_at"
    case editedBy = "edited_by"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case deletedAt = "deleted_at"
    case deletedBy = "deleted_by"
  }

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
  let deletedBy: UUID?

  func toModel() -> Note {
    let resolvedParentType: ParentType
    if let type = ParentType(rawValue: parentType) {
      resolvedParentType = type
    } else {
      #if DEBUG
      let parentTypeMessage = "⚠️ Invalid parentType '\(parentType)' for Note \(id), defaulting to .task"
      Task { @MainActor in
        debugLog.log(parentTypeMessage, category: .sync)
      }
      #endif
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
    note.deletedBy = deletedBy
    note.markSynced() // Mark as synced since it came from server
    return note
  }
}
