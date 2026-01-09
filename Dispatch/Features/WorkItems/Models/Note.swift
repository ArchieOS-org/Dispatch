//
//  Note.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

// MARK: - Note

@Model
final class Note {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    content: String,
    createdBy: UUID,
    parentType: ParentType,
    parentId: UUID,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.content = content
    self.createdBy = createdBy
    self.parentType = parentType
    self.parentId = parentId
    self.createdAt = createdAt
    updatedAt = createdAt
    syncStateRaw = .pending
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var content: String
  var createdBy: UUID
  var parentType: ParentType
  var parentId: UUID

  // Edit tracking
  var editedAt: Date?
  var editedBy: UUID?

  // Timestamps
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date? // Soft delete tombstone

  // Sync state
  var syncedAt: Date?
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Conflict tracking (Local only, not synced)
  var hasRemoteChangeWhilePending = false

  /// Computed sync state
  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

extension Note: RealtimeSyncable {
  func markPending() {
    syncState = .pending
    lastSyncError = nil
    updatedAt = Date()
  }

  func markSynced() {
    syncState = .synced
    lastSyncError = nil
    syncedAt = Date()
  }

  func markFailed(_ message: String) {
    syncState = .failed
    lastSyncError = message
  }

  func softDelete() {
    deletedAt = Date()
    markPending()
  }
}
