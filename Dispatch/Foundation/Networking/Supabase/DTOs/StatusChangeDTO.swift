//
//  StatusChangeDTO.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

struct StatusChangeDTO: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case id
    case reason
    case parentType = "parent_type"
    case parentId = "parent_id"
    case oldStatus = "old_status"
    case newStatus = "new_status"
    case changedBy = "changed_by"
    case changedAt = "changed_at"
  }

  let id: UUID
  let parentType: String
  let parentId: UUID
  let oldStatus: String?
  let newStatus: String
  let changedBy: UUID
  let changedAt: Date
  let reason: String?

  func toModel() -> StatusChange {
    let resolvedParentType: ParentType
    if let type = ParentType(rawValue: parentType) {
      resolvedParentType = type
    } else {
      debugLog.log("⚠️ Invalid parentType '\(parentType)' for StatusChange \(id), defaulting to .task", category: .sync)
      resolvedParentType = .task
    }

    return StatusChange(
      id: id,
      parentType: resolvedParentType,
      parentId: parentId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedBy: changedBy,
      changedAt: changedAt,
      reason: reason,
    )
  }
}
