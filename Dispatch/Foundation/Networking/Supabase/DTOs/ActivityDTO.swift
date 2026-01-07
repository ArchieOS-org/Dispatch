//
//  ActivityDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ActivityDTO: Codable, Sendable {
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        activityType: String,
        dueDate: Date? = nil,
        priority: String,
        status: String,
        declaredBy: UUID,
        claimedBy: UUID? = nil,
        listing: UUID? = nil,
        createdVia: String,
        sourceSlackMessages: [String]? = nil,
        audiences: [String]? = nil,
        durationMinutes: Int? = nil,
        claimedAt: Date? = nil,
        completedAt: Date? = nil,
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.activityType = activityType
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.declaredBy = declaredBy
        self.claimedBy = claimedBy
        self.listing = listing
        self.createdVia = createdVia
        self.sourceSlackMessages = sourceSlackMessages
        self.audiences = audiences
        self.durationMinutes = durationMinutes
        self.claimedAt = claimedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    let id: UUID
    let title: String
    let description: String?
    let activityType: String
    let dueDate: Date?
    let priority: String
    let status: String
    let declaredBy: UUID
    let claimedBy: UUID?
    let listing: UUID?
    let createdVia: String
    let sourceSlackMessages: [String]?
    let audiences: [String]?
    let durationMinutes: Int?
    let claimedAt: Date?
    let completedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status, listing, audiences
        case activityType = "activity_type"
        case dueDate = "due_date"
        case declaredBy = "declared_by"
        case claimedBy = "claimed_by"
        case createdVia = "created_via"
        case sourceSlackMessages = "source_slack_messages"
        case durationMinutes = "duration_minutes"
        case claimedAt = "claimed_at"
        case completedAt = "completed_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Custom Encoding (explicit null for optional fields)
    // Swift's default JSONEncoder omits nil values entirely.
    // Supabase interprets missing keys as "don't update this column".
    // We must explicitly encode null for fields like claimedBy so unclaim works.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(priority, forKey: .priority)
        try container.encode(status, forKey: .status)
        try container.encode(declaredBy, forKey: .declaredBy)
        try container.encode(createdVia, forKey: .createdVia)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)

        // Explicitly encode nil as null for nullable columns
        if let description = description {
            try container.encode(description, forKey: .description)
        } else {
            try container.encodeNil(forKey: .description)
        }
        if let dueDate = dueDate {
            try container.encode(dueDate, forKey: .dueDate)
        } else {
            try container.encodeNil(forKey: .dueDate)
        }
        if let claimedBy = claimedBy {
            try container.encode(claimedBy, forKey: .claimedBy)
        } else {
            try container.encodeNil(forKey: .claimedBy)
        }
        if let listing = listing {
            try container.encode(listing, forKey: .listing)
        } else {
            try container.encodeNil(forKey: .listing)
        }
        if let sourceSlackMessages = sourceSlackMessages {
            try container.encode(sourceSlackMessages, forKey: .sourceSlackMessages)
        } else {
            try container.encodeNil(forKey: .sourceSlackMessages)
        }
        if let audiences = audiences {
            try container.encode(audiences, forKey: .audiences)
        } else {
            try container.encodeNil(forKey: .audiences)
        }
        if let durationMinutes = durationMinutes {
            try container.encode(durationMinutes, forKey: .durationMinutes)
        } else {
            try container.encodeNil(forKey: .durationMinutes)
        }
        if let claimedAt = claimedAt {
            try container.encode(claimedAt, forKey: .claimedAt)
        } else {
            try container.encodeNil(forKey: .claimedAt)
        }
        if let completedAt = completedAt {
            try container.encode(completedAt, forKey: .completedAt)
        } else {
            try container.encodeNil(forKey: .completedAt)
        }
        if let deletedAt = deletedAt {
            try container.encode(deletedAt, forKey: .deletedAt)
        } else {
            try container.encodeNil(forKey: .deletedAt)
        }
    }

    func toModel() -> Activity {
        let resolvedType: ActivityType
        if let t = ActivityType(rawValue: activityType) {
            resolvedType = t
        } else {
            debugLog.log("⚠️ Invalid activityType '\(activityType)' for Activity \(id), defaulting to .other", category: .sync)
            resolvedType = .other
        }

        let resolvedPriority: Priority
        if let p = Priority(rawValue: priority) {
            resolvedPriority = p
        } else {
            debugLog.log("⚠️ Invalid priority '\(priority)' for Activity \(id), defaulting to .medium", category: .sync)
            resolvedPriority = .medium
        }

        let resolvedStatus: ActivityStatus
        if let s = ActivityStatus(rawValue: status) {
            resolvedStatus = s
        } else {
            debugLog.log("⚠️ Invalid status '\(status)' for Activity \(id), defaulting to .open", category: .sync)
            resolvedStatus = .open
        }

        let resolvedCreatedVia: CreationSource
        if let c = CreationSource(rawValue: createdVia) {
            resolvedCreatedVia = c
        } else {
            debugLog.log("⚠️ Invalid createdVia '\(createdVia)' for Activity \(id), defaulting to .dispatch", category: .sync)
            resolvedCreatedVia = .dispatch
        }

        return Activity(
            id: id,
            title: title,
            activityDescription: description ?? "",
            type: resolvedType,
            dueDate: dueDate,
            priority: resolvedPriority,
            status: resolvedStatus,
            declaredBy: declaredBy,
            claimedBy: claimedBy,
            listingId: listing,
            createdVia: resolvedCreatedVia,
            sourceSlackMessages: sourceSlackMessages,
            duration: durationMinutes.map { TimeInterval($0 * 60) },
            audiencesRaw: audiences ?? ["admin", "marketing"],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
