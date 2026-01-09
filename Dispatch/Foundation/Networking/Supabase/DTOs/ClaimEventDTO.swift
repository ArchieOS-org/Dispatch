//
//  ClaimEventDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct ClaimEventDTO: Codable, Sendable {

  // MARK: Lifecycle

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

  init(from model: ClaimEvent) {
    id = model.id
    parentType = model.parentType.rawValue
    parentId = model.parentId
    action = model.action.rawValue
    userId = model.userId
    performedAt = model.performedAt
    reason = model.reason
    createdAt = model.createdAt
    updatedAt = model.updatedAt
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case action
    case reason
    case parentType = "parent_type"
    case parentId = "parent_id"
    case userId = "user_id"
    case performedAt = "performed_at"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  let id: UUID
  let parentType: String
  let parentId: UUID
  let action: String
  let userId: UUID
  let performedAt: Date
  let reason: String?
  let createdAt: Date
  let updatedAt: Date

  func toModel() -> ClaimEvent {
    let resolvedParentType: ParentType
    if let type = ParentType(rawValue: parentType) {
      resolvedParentType = type
    } else {
      #if DEBUG
      Task { @MainActor in
        debugLog.log(
          "⚠️ Invalid parentType '\(parentType)' for ClaimEvent \(id), defaulting to .task",
          category: .sync
        )
      }
      #endif
      resolvedParentType = .task
    }

    let resolvedAction: ClaimAction
    if let act = ClaimAction(rawValue: action) {
      resolvedAction = act
    } else {
      #if DEBUG
      Task { @MainActor in
        debugLog.log(
          "⚠️ Invalid action '\(action)' for ClaimEvent \(id), defaulting to .claimed",
          category: .sync
        )
      }
      #endif
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

}
