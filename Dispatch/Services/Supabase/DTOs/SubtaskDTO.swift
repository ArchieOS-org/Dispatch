//
//  SubtaskDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct SubtaskDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let completed: Bool
    let parentType: String
    let parentId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, completed
        case parentType = "parent_type"
        case parentId = "parent_id"
        case createdAt = "created_at"
    }

    func toModel() -> Subtask {
        let resolvedParentType: ParentType
        if let type = ParentType(rawValue: parentType) {
            resolvedParentType = type
        } else {
            debugLog.log("⚠️ Invalid parentType '\(parentType)' for Subtask \(id), defaulting to .task", category: .sync)
            resolvedParentType = .task
        }

        return Subtask(
            id: id,
            title: title,
            completed: completed,
            parentType: resolvedParentType,
            parentId: parentId,
            createdAt: createdAt
        )
    }
}
