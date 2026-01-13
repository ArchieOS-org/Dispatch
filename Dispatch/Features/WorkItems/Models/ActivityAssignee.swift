//
//  ActivityAssignee.swift
//  Dispatch
//
//  Join table for multi-user activity assignments.
//  Replaces single-user claimedBy pattern.
//

import Foundation
import SwiftData

// MARK: - ActivityAssignee

/// Represents an assignment of a user to an activity.
/// Join table enabling multi-assignee support with assignment metadata.
@Model
final class ActivityAssignee {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    activityId: UUID,
    userId: UUID,
    assignedBy: UUID,
    assignedAt: Date = Date(),
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.activityId = activityId
    self.userId = userId
    self.assignedBy = assignedBy
    self.assignedAt = assignedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID

  /// Foreign key to activities table
  var activityId: UUID

  /// Foreign key to users table - the assigned user
  var userId: UUID

  /// Foreign key to users table - who made the assignment
  var assignedBy: UUID

  /// When the assignment was made
  var assignedAt: Date

  // Timestamps
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Relationship to parent activity
  var activity: Activity?

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

extension ActivityAssignee: RealtimeSyncable {

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

}
