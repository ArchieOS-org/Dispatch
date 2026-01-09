//
//  ClaimEvent.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

// MARK: - ClaimEvent

@Model
final class ClaimEvent {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    parentType: ParentType,
    parentId: UUID,
    action: ClaimAction,
    userId: UUID,
    performedAt: Date = Date(),
    reason: String? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
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
    syncStateRaw = .pending // Local creates start pending, server upserts mark .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var parentType: ParentType
  var parentId: UUID
  var action: ClaimAction
  var userId: UUID
  var performedAt: Date
  var reason: String?
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking - optional storage with computed wrapper for schema migration compatibility
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

extension ClaimEvent: RealtimeSyncable {
  // syncState, lastSyncError, syncedAt are stored properties
  // isDirty, isSyncFailed computed from syncState via protocol extension
  // conflictResolution uses default from protocol extension (.lastWriteWins)

  /// Mark as pending when modified
  func markPending() {
    syncState = .pending
    lastSyncError = nil
    updatedAt = Date()
  }

  /// Mark as synced after successful sync
  func markSynced() {
    syncState = .synced
    lastSyncError = nil
    syncedAt = Date()
  }

  /// Mark as failed with error message
  func markFailed(_ message: String) {
    syncState = .failed
    lastSyncError = message
  }
}
