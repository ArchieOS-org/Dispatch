//
//  ActivityDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ActivityDTO: Codable, Sendable {
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
    let durationMinutes: Int?
    let claimedAt: Date?
    let completedAt: Date?
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status, listing
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

    func toModel() -> Activity {
        Activity(
            id: id,
            title: title,
            activityDescription: description ?? "",
            type: ActivityType(rawValue: activityType) ?? .other,
            dueDate: dueDate,
            priority: Priority(rawValue: priority) ?? .medium,
            status: ActivityStatus(rawValue: status) ?? .open,
            declaredBy: declaredBy,
            claimedBy: claimedBy,
            listingId: listing,
            createdVia: CreationSource(rawValue: createdVia) ?? .dispatch,
            sourceSlackMessages: sourceSlackMessages,
            duration: durationMinutes.map { TimeInterval($0 * 60) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
