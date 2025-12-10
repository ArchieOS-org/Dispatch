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
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
