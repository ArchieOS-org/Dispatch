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
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, action, reason
        case parentType = "parent_type"
        case parentId = "parent_id"
        case userId = "user_id"
        case performedAt = "performed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        parentType: String,
        parentId: UUID,
        action: String,
        userId: UUID,
        performedAt: Date,
        reason: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.parentType = parentType
        self.parentId = parentId
        self.action = action
        self.userId = userId
        self.performedAt = performedAt
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toModel() -> ClaimEvent {
        let resolvedParentType: ParentType
        if let type = ParentType(rawValue: parentType) {
            resolvedParentType = type
        } else {
            debugLog.log("⚠️ Invalid parentType '\(parentType)' for ClaimEvent \(id), defaulting to .task", category: .sync)
            resolvedParentType = .task
        }

        let resolvedAction: ClaimAction
        if let act = ClaimAction(rawValue: action) {
            resolvedAction = act
        } else {
            debugLog.log("⚠️ Invalid action '\(action)' for ClaimEvent \(id), defaulting to .claimed", category: .sync)
            resolvedAction = .claimed
        }

        return ClaimEvent(
            id: id,
            parentType: resolvedParentType,
            parentId: parentId,
            action: resolvedAction,
            userId: userId,
            performedAt: performedAt,
            reason: reason,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    init(from model: ClaimEvent) {
        self.id = model.id
        self.parentType = model.parentType.rawValue
        self.parentId = model.parentId
        self.action = model.action.rawValue
        self.userId = model.userId
        self.performedAt = model.performedAt
        self.reason = model.reason
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}
