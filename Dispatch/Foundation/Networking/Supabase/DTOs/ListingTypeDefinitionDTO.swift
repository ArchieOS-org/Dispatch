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
    isSystem = model.isSystem
    position = model.position
    isArchived = model.isArchived
    ownedBy = model.ownedBy
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case position
    case isSystem = "is_system"
    case isArchived = "is_archived"
    case ownedBy = "owned_by"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let name: String
  let isSystem: Bool
  let position: Int
  let isArchived: Bool
  let ownedBy: UUID?
  let createdAt: Date
  let updatedAt: Date

  /// Create SwiftData model from DTO (for SyncDown)
  func toModel() -> ListingTypeDefinition {
    ListingTypeDefinition(
      id: id,
      name: name,
      isSystem: isSystem,
      position: position,
      isArchived: isArchived,
      ownedBy: ownedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    )
  }
}
