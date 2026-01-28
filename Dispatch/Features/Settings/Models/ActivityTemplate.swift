//
//  ActivityTemplate.swift
//  Dispatch
//
//  Template for auto-generated activities linked to listing types.
//  Created for Listing Types & Activity Templates feature.
//

import Foundation
import SwiftData

// MARK: - ActivityTemplate

@Model
final class ActivityTemplate {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    title: String,
    templateDescription: String = "",
    position: Int = 0,
    isArchived: Bool = false,
    audiencesRaw: [String] = [],
    listingTypeId: UUID,
    defaultAssigneeId: UUID? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.templateDescription = templateDescription
    self.position = position
    self.isArchived = isArchived
    self.audiencesRaw = audiencesRaw
    self.listingTypeId = listingTypeId
    self.defaultAssigneeId = defaultAssigneeId
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var title: String
  var templateDescription: String
  var position: Int
  var isArchived: Bool

  /// Audience targeting - stored as [String] for SwiftData compatibility
  var audiencesRaw = [String]()

  // Foreign keys
  var listingTypeId: UUID
  var defaultAssigneeId: UUID?

  // Timestamps
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  // Relationships
  var listingType: ListingTypeDefinition?
  var defaultAssignee: User?

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

extension ActivityTemplate: RealtimeSyncable {
  /// Mark as pending when modified.
  /// During sync, relationship mutations trigger SwiftData dirty tracking.
  /// Suppress state changes to prevent sync loops.
  @MainActor
  func markPending() {
    guard !shouldSuppressPending else { return }
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
