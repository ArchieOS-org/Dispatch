//
//  ActivityTemplateDTO.swift
//  Dispatch
//
//  DTO for syncing ActivityTemplate with Supabase.
//

import Foundation

struct ActivityTemplateDTO: Codable, Sendable {

  // MARK: Lifecycle

  /// Create DTO from SwiftData model (for SyncUp)
  init(from model: ActivityTemplate) {
    id = model.id
    title = model.title
    description = model.templateDescription
    position = model.position
    isArchived = model.isArchived
    audiences = model.audiencesRaw
    listingTypeId = model.listingTypeId
    defaultAssigneeId = model.defaultAssigneeId
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case description
    case position
    case audiences
    case isArchived = "is_archived"
    case listingTypeId = "listing_type_id"
    case defaultAssigneeId = "default_assignee_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

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
