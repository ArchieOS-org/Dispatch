//
//  ListingTypeDefinition.swift
//  Dispatch
//
//  Dynamic listing type definition for auto-generated activities.
//  Created for Listing Types & Activity Templates feature.
//

import Foundation
import SwiftData

// MARK: - ListingTypeDefinition

@Model
final class ListingTypeDefinition {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    name: String,
    position: Int = 0,
    isArchived: Bool = false,
    ownedBy: UUID? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.position = position
    self.isArchived = isArchived
    self.ownedBy = ownedBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var name: String
  var position: Int
  var isArchived: Bool

  /// Foreign keys
  var ownedBy: UUID?

  // Timestamps
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Relationships
  @Relationship(deleteRule: .cascade, inverse: \ActivityTemplate.listingType)
  var templates = [ActivityTemplate]()

  @Relationship(inverse: \Listing.typeDefinition)
  var listings = [Listing]()

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

extension ListingTypeDefinition: RealtimeSyncable {
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
