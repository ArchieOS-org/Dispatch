//
//  ListingTypeDefinitionDTO.swift
//  Dispatch
//
//  DTO for syncing ListingTypeDefinition with Supabase.
//

import Foundation

struct ListingTypeDefinitionDTO: Codable, Sendable {

  // MARK: Lifecycle

  /// Create DTO from SwiftData model (for SyncUp)
  init(from model: ListingTypeDefinition) {
    id = model.id
    name = model.name
    position = model.position
    isArchived = model.isArchived
    colorHex = model.colorHex
    ownedBy = model.ownedBy
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case position
    case isArchived = "is_archived"
    case colorHex = "color_hex"
    case ownedBy = "owned_by"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let name: String
  let position: Int
  let isArchived: Bool
  let colorHex: String?
  let ownedBy: UUID?
  let createdAt: Date
  let updatedAt: Date

  /// Create SwiftData model from DTO (for SyncDown)
  func toModel() -> ListingTypeDefinition {
    ListingTypeDefinition(
      id: id,
      name: name,
      position: position,
      isArchived: isArchived,
      colorHex: colorHex,
      ownedBy: ownedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
