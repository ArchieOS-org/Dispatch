//
//  ClaimEventDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ClaimEventDTO: Codable, Sendable {
    let id: UUID
    let parentType: String
    let parentId: UUID
    let action: String
    let userId: UUID
    let performedAt: Date
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id, action, reason
        case parentType = "parent_type"
        case parentId = "parent_id"
        case userId = "user_id"
        case performedAt = "performed_at"
    }

    func toModel() -> ClaimEvent {
        ClaimEvent(
            id: id,
            parentType: ParentType(rawValue: parentType) ?? .task,
            parentId: parentId,
            action: ClaimAction(rawValue: action) ?? .claimed,
            userId: userId,
            performedAt: performedAt,
            reason: reason
        )
    }
}
