//
//  Activity.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

// MARK: - Activity

@Model
final class Activity: WorkItemProtocol, NotableProtocol {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    title: String,
    activityDescription: String = "",
    dueDate: Date? = nil,
    status: ActivityStatus = .open,
    declaredBy: UUID,
    listingId: UUID? = nil,
    createdVia: CreationSource = .dispatch,
    sourceSlackMessages: [String]? = nil,
    duration: TimeInterval? = nil,
    audiencesRaw: [String] = ["admin", "marketing"],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.activityDescription = activityDescription
    self.dueDate = dueDate
    self.status = status
    self.declaredBy = declaredBy
    self.listingId = listingId
    self.createdVia = createdVia
    self.sourceSlackMessages = sourceSlackMessages
    self.duration = duration
    self.audiencesRaw = audiencesRaw
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  /// Convenience initializer for previews/testing that accepts assignee user IDs
  convenience init(
    id: UUID = UUID(),
    title: String,
    activityDescription: String = "",
    dueDate: Date? = nil,
    status: ActivityStatus = .open,
    declaredBy: UUID,
    listingId: UUID? = nil,
    assigneeUserIds: [UUID],
    createdVia: CreationSource = .dispatch,
    sourceSlackMessages: [String]? = nil,
    duration: TimeInterval? = nil,
    audiencesRaw: [String] = ["admin", "marketing"],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.init(
      id: id,
      title: title,
      activityDescription: activityDescription,
      dueDate: dueDate,
      status: status,
      declaredBy: declaredBy,
      listingId: listingId,
      createdVia: createdVia,
      sourceSlackMessages: sourceSlackMessages,
      duration: duration,
      audiencesRaw: audiencesRaw,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
    // Create ActivityAssignee objects for each user ID
    for userId in assigneeUserIds {
      let assignee = ActivityAssignee(
        activityId: id,
        userId: userId,
        assignedBy: declaredBy,
        assignedAt: createdAt,
        createdAt: createdAt,
        updatedAt: updatedAt
      )
      assignee.activity = self
      assignees.append(assignee)
    }
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var title: String
  var activityDescription: String
  var dueDate: Date?
  var status: ActivityStatus

  // Foreign keys
  var declaredBy: UUID
  var listingId: UUID?
  var sourceTemplateId: UUID? // For idempotency: links to ActivityTemplate that generated this

  // Metadata
  var createdVia: CreationSource
  var sourceSlackMessages: [String]?
  var duration: TimeInterval?

  /// Audience targeting - stored as [String] for SwiftData compatibility
  /// Default value at property level required for SwiftData schema migration
  var audiencesRaw: [String] = ["admin", "marketing"]

  // Timestamps
  var completedAt: Date?
  var deletedAt: Date?
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking - optional storage with computed wrapper for schema migration compatibility
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Relationships
  @Relationship(deleteRule: .cascade)
  var notes = [Note]()

  @Relationship(deleteRule: .cascade)
  var subtasks = [Subtask]()

  @Relationship(deleteRule: .cascade)
  var statusHistory = [StatusChange]()

  @Relationship(deleteRule: .cascade, inverse: \ActivityAssignee.activity)
  var assignees = [ActivityAssignee]()

  // Inverse relationships
  var listing: Listing?
  var sourceTemplate: ActivityTemplate? // Source template that generated this activity

  /// Convenience computed property for assignee user IDs
  var assigneeUserIds: [UUID] {
    assignees.map { $0.userId }
  }

  /// Computed property exposing audiences as Set<Role>
  var audiences: Set<Role> {
    get {
      Set(audiencesRaw.compactMap { Role(rawValue: $0) })
    }
    set {
      audiencesRaw = newValue.map { $0.rawValue }
    }
  }

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

extension Activity: RealtimeSyncable {
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
