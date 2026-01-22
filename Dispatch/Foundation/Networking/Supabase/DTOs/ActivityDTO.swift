//
//  ActivityDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ActivityDTO: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case description
    case status
    case listing
    case audiences
    case dueDate = "due_date"
    case declaredBy = "declared_by"
    case createdVia = "created_via"
    case sourceSlackMessages = "source_slack_messages"
    case durationMinutes = "duration_minutes"
    case completedAt = "completed_at"
    case deletedAt = "deleted_at"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let title: String
  let description: String?
  let dueDate: Date?
  let status: String
  let declaredBy: UUID
  let listing: UUID? // Supabase column is "listing" not "listing_id"
  let createdVia: String
  let sourceSlackMessages: [String]?
  let audiences: [String]?
  let durationMinutes: Int?
  let completedAt: Date?
  let deletedAt: Date?
  let createdAt: Date
  let updatedAt: Date

  /// Swift's default JSONEncoder omits nil values entirely.
  /// Supabase interprets missing keys as "don't update this column".
  /// We must explicitly encode null for nullable columns.
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(status, forKey: .status)
    try container.encode(declaredBy, forKey: .declaredBy)
    try container.encode(createdVia, forKey: .createdVia)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)

    // Explicitly encode nil as null for nullable columns
    if let description {
      try container.encode(description, forKey: .description)
    } else {
      try container.encodeNil(forKey: .description)
    }
    if let dueDate {
      try container.encode(dueDate, forKey: .dueDate)
    } else {
      try container.encodeNil(forKey: .dueDate)
    }
    if let listing {
      try container.encode(listing, forKey: .listing)
    } else {
      try container.encodeNil(forKey: .listing)
    }
    if let sourceSlackMessages {
      try container.encode(sourceSlackMessages, forKey: .sourceSlackMessages)
    } else {
      try container.encodeNil(forKey: .sourceSlackMessages)
    }
    if let audiences {
      try container.encode(audiences, forKey: .audiences)
    } else {
      try container.encodeNil(forKey: .audiences)
    }
    if let durationMinutes {
      try container.encode(durationMinutes, forKey: .durationMinutes)
    } else {
      try container.encodeNil(forKey: .durationMinutes)
    }
    if let completedAt {
      try container.encode(completedAt, forKey: .completedAt)
    } else {
      try container.encodeNil(forKey: .completedAt)
    }
    if let deletedAt {
      try container.encode(deletedAt, forKey: .deletedAt)
    } else {
      try container.encodeNil(forKey: .deletedAt)
    }
  }

  func toModel() -> Activity {
    let resolvedStatus: ActivityStatus
    if let s = ActivityStatus(rawValue: status) {
      resolvedStatus = s
    } else {
      #if DEBUG
      let statusMessage = "⚠️ Invalid status '\(status)' for Activity \(id), defaulting to .open"
      Task { @MainActor in
        debugLog.log(statusMessage, category: .sync)
      }
      #endif
      resolvedStatus = .open
    }

    let resolvedCreatedVia: CreationSource
    if let c = CreationSource(rawValue: createdVia) {
      resolvedCreatedVia = c
    } else {
      #if DEBUG
      let createdViaMessage = "⚠️ Invalid createdVia '\(createdVia)' for Activity \(id), defaulting to .dispatch"
      Task { @MainActor in
        debugLog.log(createdViaMessage, category: .sync)
      }
      #endif
      resolvedCreatedVia = .dispatch
    }

    // Normalize audiences to enforce mutual exclusivity (admin > marketing > default to admin)
    let normalizedAudiences = normalizeAudiences(audiences)

    return Activity(
      id: id,
      title: title,
      activityDescription: description ?? "",
      dueDate: dueDate,
      status: resolvedStatus,
      declaredBy: declaredBy,
      listingId: listing,
      createdVia: resolvedCreatedVia,
      sourceSlackMessages: sourceSlackMessages,
      duration: durationMinutes.map { TimeInterval($0 * 60) },
      audiencesRaw: normalizedAudiences,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
