//
//  NoteUpdateDTO.swift
//  Dispatch
//
//  Created by Claude on 2026-01-12.
//

import Foundation

/// DTO for updating existing notes - contains only mutable columns + id.
/// This ensures upsert operations don't attempt to modify immutable columns
/// (created_by, parent_type, parent_id, created_at) which would violate
/// column-level UPDATE grants and architectural constraints.
struct NoteUpdateDTO: Codable, Sendable {

  // MARK: Lifecycle

  init(from model: Note) {
    id = model.id
    content = model.content
    editedAt = model.editedAt
    editedBy = model.editedBy
    updatedAt = model.updatedAt
    deletedAt = model.deletedAt
    deletedBy = model.deletedBy
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case content
    case editedAt = "edited_at"
    case editedBy = "edited_by"
    case updatedAt = "updated_at"
    case deletedAt = "deleted_at"
    case deletedBy = "deleted_by"
  }

  let id: UUID
  let content: String
  let editedAt: Date?
  let editedBy: UUID?
  let updatedAt: Date?
  let deletedAt: Date?
  let deletedBy: UUID?
}
