//
//  ListingTypeDefinitionDTO.swift
//  Dispatch
//
//  DTO for syncing ListingTypeDefinition with Supabase.
//

import Foundation

struct ListingTypeDefinitionDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let isSystem: Bool
    let position: Int
    let isArchived: Bool
    let ownedBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, position
        case isSystem = "is_system"
        case isArchived = "is_archived"
        case ownedBy = "owned_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Create DTO from SwiftData model (for SyncUp)
    init(from model: ListingTypeDefinition) {
        self.id = model.id
        self.name = model.name
        self.isSystem = model.isSystem
        self.position = model.position
        self.isArchived = model.isArchived
        self.ownedBy = model.ownedBy
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }

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
            updatedAt: updatedAt
        )
    }
}
