//
//  PendingDeletion.swift
//  Dispatch
//
//  Tombstone record that tracks local deletes pending sync to Supabase.
//  When user deletes an entity, we:
//  1. Delete from SwiftData (immediate local effect)
//  2. Create a PendingDeletion tombstone (tracks sync intent)
//  3. Process tombstones on sync (issues DELETE to Supabase)
//  4. Remove tombstone on success (sync complete)
//

import Foundation
import SwiftData

// MARK: - PendingDeletion

@Model
final class PendingDeletion {

  // MARK: Lifecycle

  init(entityType: AuditableEntity, entityId: UUID) {
    id = UUID()
    self.entityType = entityType.rawValue
    self.entityId = entityId
    deletedAt = Date()
    retryCount = 0
    lastError = nil
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var entityType: String
  var entityId: UUID
  var deletedAt: Date
  var retryCount: Int
  var lastError: String?

  var auditableEntityType: AuditableEntity? {
    AuditableEntity(rawValue: entityType)
  }
}
