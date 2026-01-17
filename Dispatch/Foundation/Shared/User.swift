//
//  User.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

// MARK: - User

@Model
final class User {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    authId: UUID? = nil,
    name: String,
    email: String,
    avatar: Data? = nil,
    avatarHash: String? = nil,
    userType: UserType,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.authId = authId
    self.name = name
    self.email = email
    self.avatar = avatar
    self.avatarHash = avatarHash
    self.userType = userType
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var authId: UUID? // Links to Supabase Auth (Shadow Profile support)
  var name: String
  var email: String
  var avatar: Data?
  var avatarHash: String?
  var userType: UserType

  // Timestamps
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking - optional storage with computed wrapper for schema migration compatibility
  // Note: Users sync DOWN only (RLS prevents non-self updates), so these are primarily for protocol conformance
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Relationships (for realtors)
  @Relationship(deleteRule: .nullify, inverse: \Listing.owner)
  var listings = [Listing]()

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

/// NOTE: Users sync DOWN only (RLS prevents non-self updates)
extension User: RealtimeSyncable {
  // syncState, lastSyncError, syncedAt are stored properties
  // isDirty, isSyncFailed computed from syncState via protocol extension
  // conflictResolution uses default from protocol extension (.lastWriteWins)

  /// Mark as pending when modified (rarely used for User - sync is mostly down)
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
