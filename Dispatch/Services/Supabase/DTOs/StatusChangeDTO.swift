//
//  StatusChangeDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct StatusChangeDTO: Codable, Sendable {
    let id: UUID
    let parentType: String
    let parentId: UUID
    let oldStatus: String?
    let newStatus: String
    let changedBy: UUID
    let changedAt: Date
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id, reason
        case parentType = "parent_type"
        case parentId = "parent_id"
        case oldStatus = "old_status"
        case newStatus = "new_status"
        case changedBy = "changed_by"
        case changedAt = "changed_at"
    }

    func toModel() -> StatusChange {
        StatusChange(
            id: id,
            parentType: ParentType(rawValue: parentType) ?? .task,
            parentId: parentId,
            oldStatus: oldStatus,
            newStatus: newStatus,
            changedBy: changedBy,
            changedAt: changedAt,
            reason: reason
        )
    }
}
