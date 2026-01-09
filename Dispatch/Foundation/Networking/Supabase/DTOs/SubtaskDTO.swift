//
//  SubtaskDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct SubtaskDTO: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case completed
    case parentType = "parent_type"
    case parentId = "parent_id"
    case createdAt = "created_at"
  }

  let id: UUID
  let title: String
  let completed: Bool
  let parentType: String
  let parentId: UUID
  let createdAt: Date

  func toModel() -> Subtask {
    let resolvedParentType: ParentType
    if let type = ParentType(rawValue: parentType) {
      resolvedParentType = type
    } else {
      #if DEBUG
      let parentTypeMessage = "⚠️ Invalid parentType '\(parentType)' for Subtask \(id), defaulting to .task"
      Task { @MainActor in
        debugLog.log(parentTypeMessage, category: .sync)
      }
      #endif
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
