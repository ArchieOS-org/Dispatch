//
//  Listing.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation
import SwiftData

// MARK: - Listing

@Model
final class Listing: NotableProtocol {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    address: String,
    city: String = "",
    province: String = "",
    postalCode: String = "",
    country: String = "Canada",
    price: Decimal? = nil,
    mlsNumber: String? = nil,
    listingType: ListingType = .sale,
    status: ListingStatus = .draft,
    stage: ListingStage = .pending,
    ownedBy: UUID,
    createdVia: CreationSource = .dispatch,
    sourceSlackMessages: [String]? = nil,
    dueDate: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.address = address
    self.city = city
    self.province = province
    self.postalCode = postalCode
    self.country = country
    self.price = price
    self.mlsNumber = mlsNumber
    self.listingType = listingType
    self.status = status
    stageRaw = stage
    self.ownedBy = ownedBy
    self.createdVia = createdVia
    self.sourceSlackMessages = sourceSlackMessages
    self.dueDate = dueDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var address: String
  var city: String
  var province: String
  var postalCode: String
  var country: String
  var price: Decimal?
  var mlsNumber: String?
  var realDirt: String?
  var listingType: ListingType
  var status: ListingStatus
  var stageRaw: ListingStage?

  // Foreign keys
  var ownedBy: UUID
  var propertyId: UUID?
  var typeDefinitionId: UUID? // Links to ListingTypeDefinition (nullable during client transition)

  // Metadata
  var createdVia: CreationSource
  var sourceSlackMessages: [String]?

  // Timestamps
  var activatedAt: Date?
  var pendingAt: Date?
  var closedAt: Date?
  var deletedAt: Date?
  var dueDate: Date?
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking - optional storage with computed wrapper for schema migration compatibility
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Tracks retry attempts for failed sync operations. Persisted across app restarts.
  /// Reset to 0 on successful sync.
  var retryCount: Int = 0

  /// Tracks when auto-recovery last reset this entity. Used to enforce cooldown period
  /// to prevent rapid re-reset loops when underlying issues persist.
  /// Marked @Transient to exclude from persistence - this is a runtime-only value.
  @Transient var lastResetAttempt: Date?

  /// Relationships
  @Relationship(deleteRule: .cascade)
  var tasks = [TaskItem]()

  @Relationship(deleteRule: .cascade)
  var activities = [Activity]()

  @Relationship(deleteRule: .cascade)
  var notes = [Note]()

  @Relationship(deleteRule: .cascade)
  var statusHistory = [StatusChange]()

  /// Inverse relationships
  var owner: User?

  /// Dynamic type definition relationship (Non-Optional post-migration)
  var typeDefinition: ListingTypeDefinition?

  /// Property relationship
  @Relationship(deleteRule: .nullify)
  var property: Property?

  /// Computed stage with fallback for schema migration compatibility
  var stage: ListingStage {
    get { stageRaw ?? .pending }
    set { stageRaw = newValue }
  }

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

}

// MARK: RealtimeSyncable

extension Listing: RealtimeSyncable {
  // syncState, lastSyncError, syncedAt are stored properties
  // isDirty, isSyncFailed computed from syncState via protocol extension
  // conflictResolution uses default from protocol extension (.lastWriteWins)

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

  /// Mark as synced after successful sync
  func markSynced() {
    syncState = .synced
    lastSyncError = nil
    syncedAt = Date()
    retryCount = 0
  }

  /// Mark as failed with error message
  func markFailed(_ message: String) {
    syncState = .failed
    lastSyncError = message
  }
}
