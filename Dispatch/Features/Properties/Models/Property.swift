//
//  Property.swift
//  Dispatch
//
//  Property entity - groups multiple listings at a single location
//

import Foundation
import SwiftData

// MARK: - Property

@Model
final class Property {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    address: String,
    unit: String? = nil,
    city: String = "",
    province: String = "",
    postalCode: String = "",
    country: String = "Canada",
    propertyType: PropertyType = .residential,
    ownedBy: UUID,
    createdVia: CreationSource = .dispatch,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.address = address
    self.unit = unit
    self.city = city
    self.province = province
    self.postalCode = postalCode
    self.country = country
    self.propertyType = propertyType
    self.ownedBy = ownedBy
    self.createdVia = createdVia
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    syncStateRaw = .synced
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var address: String
  var unit: String?
  var city: String
  var province: String
  var postalCode: String
  var country: String
  var propertyType: PropertyType

  /// Foreign keys
  var ownedBy: UUID

  /// Metadata
  var createdVia: CreationSource

  // Timestamps
  var deletedAt: Date?
  var createdAt: Date
  var updatedAt: Date
  var syncedAt: Date?

  // Sync state tracking
  var syncStateRaw: EntitySyncState?
  var lastSyncError: String?

  /// Relationships
  @Relationship(deleteRule: .nullify, inverse: \Listing.property)
  var listings = [Listing]()

  /// Inverse relationships
  var owner: User?

  var syncState: EntitySyncState {
    get { syncStateRaw ?? .synced }
    set { syncStateRaw = newValue }
  }

  /// Computed
  var activeListings: [Listing] {
    listings.filter { $0.deletedAt == nil }
  }

  var displayAddress: String {
    if let unit, !unit.isEmpty {
      return "\(address), Unit \(unit)"
    }
    return address
  }

}

// MARK: RealtimeSyncable

extension Property: RealtimeSyncable {
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
  }

  /// Mark as failed with error message
  func markFailed(_ message: String) {
    syncState = .failed
    lastSyncError = message
  }
}
