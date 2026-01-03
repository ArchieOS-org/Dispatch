//
//  ActivityTemplateDTO.swift
//  Dispatch
//
//  DTO for syncing ActivityTemplate with Supabase.
//

import Foundation

struct ActivityTemplateDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let position: Int
    let isArchived: Bool
    let audiences: [String]
    let listingTypeId: UUID
    let defaultAssigneeId: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, position, audiences
        case isArchived = "is_archived"
        case listingTypeId = "listing_type_id"
        case defaultAssigneeId = "default_assignee_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Create DTO from SwiftData model (for SyncUp)
    init(from model: ActivityTemplate) {
        self.id = model.id
        self.title = model.title
        self.description = model.templateDescription
        self.position = model.position
        self.isArchived = model.isArchived
        self.audiences = model.audiencesRaw
        self.listingTypeId = model.listingTypeId
        self.defaultAssigneeId = model.defaultAssigneeId
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }

    /// Create SwiftData model from DTO (for SyncDown)
    func toModel() -> ActivityTemplate {
        ActivityTemplate(
            id: id,
            title: title,
            templateDescription: description,
            position: position,
            isArchived: isArchived,
            audiencesRaw: audiences,
            listingTypeId: listingTypeId,
            defaultAssigneeId: defaultAssigneeId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
