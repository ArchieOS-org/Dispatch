//
//  PropertySyncHandlerTests.swift
//  DispatchTests
//
//  Unit tests for PropertySyncHandler entity-specific sync operations.
//  Tests upsertProperty logic including local-authoritative protection.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - PropertySyncHandlerTests

@MainActor
final class PropertySyncHandlerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container for testing
    let schema = Schema([Property.self, Listing.self, User.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    container = try! ModelContainer(for: schema, configurations: [config])
    context = ModelContext(container)

    // Create dependencies for test mode
    conflictResolver = ConflictResolver()
    let deps = SyncHandlerDependencies(
      mode: .test,
      conflictResolver: conflictResolver,
      getCurrentUserID: { nil },
      getCurrentUser: { nil },
      fetchCurrentUser: { _ in },
      updateListingConfigReady: { _ in }
    )
    handler = PropertySyncHandler(dependencies: deps)
  }

  override func tearDown() {
    context = nil
    container = nil
    handler = nil
    conflictResolver = nil
    super.tearDown()
  }

  // MARK: - Initialization Tests

  func test_init_setsModeProperly() {
    XCTAssertEqual(handler.dependencies.mode, .test)
  }

  func test_init_setsConflictResolver() {
    XCTAssertNotNil(handler.dependencies.conflictResolver)
  }

  // MARK: - upsertProperty Tests

  func test_upsertProperty_insertsNewProperty() throws {
    // Given: A new property DTO that doesn't exist locally
    let propertyId = UUID()
    let dto = makePropertyDTO(id: propertyId, address: "123 Main Street")

    // When: Upsert the property
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Property should be inserted
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    XCTAssertEqual(properties.count, 1)
    XCTAssertEqual(properties.first?.address, "123 Main Street")
    XCTAssertEqual(properties.first?.syncState, .synced)
  }

  func test_upsertProperty_updatesExistingProperty() throws {
    // Given: An existing synced property
    let propertyId = UUID()
    let existingProperty = makeProperty(id: propertyId, address: "Old Address")
    existingProperty.markSynced()
    context.insert(existingProperty)
    try context.save()

    // When: Upsert with updated address
    let dto = makePropertyDTO(id: propertyId, address: "Updated Address")
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Property should be updated
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    XCTAssertEqual(properties.first?.address, "Updated Address")
    XCTAssertEqual(properties.first?.syncState, .synced)
  }

  func test_upsertProperty_skipsPendingProperty() throws {
    // Given: A property with pending local changes
    let propertyId = UUID()
    let existingProperty = makeProperty(id: propertyId, address: "Pending local edit")
    existingProperty.markPending()
    existingProperty.updatedAt = Date().addingTimeInterval(1)
    context.insert(existingProperty)
    try context.save()

    // When: Upsert remote update while pending
    let dto = makePropertyDTO(id: propertyId, address: "Remote address")
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Local content should be preserved (local-authoritative)
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    XCTAssertEqual(properties.first?.address, "Pending local edit")
    XCTAssertEqual(properties.first?.syncState, .pending)
  }

  func test_upsertProperty_skipsFailedProperty() throws {
    // Given: A property with failed sync state
    let propertyId = UUID()
    let existingProperty = makeProperty(id: propertyId, address: "Failed local edit")
    existingProperty.markFailed("Sync error")
    context.insert(existingProperty)
    try context.save()

    // When: Upsert remote update while failed
    let dto = makePropertyDTO(id: propertyId, address: "Remote address")
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Local content should be preserved (local-authoritative)
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    XCTAssertEqual(properties.first?.address, "Failed local edit")
    XCTAssertEqual(properties.first?.syncState, .failed)
  }

  func test_upsertProperty_handlesSoftDelete() throws {
    // Given: An existing property
    let propertyId = UUID()
    let existingProperty = makeProperty(id: propertyId, address: "Original address")
    existingProperty.markSynced()
    context.insert(existingProperty)
    try context.save()

    // When: Upsert with deletedAt set (soft delete from remote)
    let deletedDate = Date()
    let dto = makePropertyDTO(
      id: propertyId,
      address: "Original address",
      deletedAt: deletedDate
    )
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Property should have deletedAt set
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    XCTAssertNotNil(properties.first?.deletedAt)
    XCTAssertEqual(properties.first?.syncState, .synced)
  }

  func test_upsertProperty_nullifiesListingsOnDelete() throws {
    // Given: A property with associated listings
    let propertyId = UUID()
    let ownerId = UUID()
    let existingProperty = makeProperty(id: propertyId, address: "Property with listings", ownedBy: ownerId)
    existingProperty.markSynced()
    context.insert(existingProperty)

    let listing = Listing(
      address: "123 Main St",
      ownedBy: ownerId
    )
    listing.property = existingProperty
    listing.markSynced()
    context.insert(listing)
    try context.save()

    // Verify listing is linked to property
    XCTAssertNotNil(listing.property)
    XCTAssertEqual(listing.property?.id, propertyId)

    // When: Property is deleted via context (simulating cascade behavior)
    context.delete(existingProperty)
    try context.save()

    // Then: Listing should still exist but with nullified property relationship
    let listingDescriptor = FetchDescriptor<Listing>()
    let listings = try context.fetch(listingDescriptor)
    XCTAssertEqual(listings.count, 1)
    XCTAssertNil(listings.first?.property) // Relationship nullified, not cascade deleted
  }

  func test_upsertProperty_updatesAllFields() throws {
    // Given: An existing synced property
    let propertyId = UUID()
    let ownerId = UUID()
    let existingProperty = makeProperty(
      id: propertyId,
      address: "Old Address",
      unit: "1A",
      city: "Old City",
      province: "Old Province",
      postalCode: "A1A 1A1",
      country: "Old Country",
      propertyType: .residential,
      ownedBy: ownerId
    )
    existingProperty.markSynced()
    context.insert(existingProperty)
    try context.save()

    // When: Upsert with all fields updated
    let dto = makePropertyDTO(
      id: propertyId,
      address: "New Address",
      unit: "2B",
      city: "New City",
      province: "New Province",
      postalCode: "B2B 2B2",
      country: "New Country",
      propertyType: "commercial",
      ownedBy: ownerId
    )
    try handler.upsertProperty(dto: dto, context: context)

    // Then: All fields should be updated
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    let property = try XCTUnwrap(properties.first)
    XCTAssertEqual(property.address, "New Address")
    XCTAssertEqual(property.unit, "2B")
    XCTAssertEqual(property.city, "New City")
    XCTAssertEqual(property.province, "New Province")
    XCTAssertEqual(property.postalCode, "B2B 2B2")
    XCTAssertEqual(property.country, "New Country")
    XCTAssertEqual(property.propertyType, .commercial)
    XCTAssertEqual(property.syncState, .synced)
  }

  func test_upsertProperty_handlesNilOptionalFields() throws {
    // Given: A new property DTO with nil optional fields
    let propertyId = UUID()
    let dto = makePropertyDTO(
      id: propertyId,
      address: "Minimal Address",
      unit: nil,
      city: nil,
      province: nil,
      postalCode: nil,
      country: nil
    )

    // When: Upsert the property
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Property should have default values for optional fields
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    let property = try XCTUnwrap(properties.first)
    XCTAssertEqual(property.address, "Minimal Address")
    XCTAssertNil(property.unit)
    XCTAssertEqual(property.city, "")
    XCTAssertEqual(property.province, "")
    XCTAssertEqual(property.postalCode, "")
    XCTAssertEqual(property.country, "Canada") // Default country
  }

  func test_upsertProperty_resurrectsSoftDeletedProperty() throws {
    // Given: A soft-deleted property
    let propertyId = UUID()
    let existingProperty = makeProperty(id: propertyId, address: "Deleted property")
    existingProperty.deletedAt = Date()
    existingProperty.markSynced()
    context.insert(existingProperty)
    try context.save()

    // When: Upsert with no deletedAt (resurrection)
    let dto = makePropertyDTO(id: propertyId, address: "Resurrected property")
    try handler.upsertProperty(dto: dto, context: context)

    // Then: Property should be resurrected
    let descriptor = FetchDescriptor<Property>(predicate: #Predicate { $0.id == propertyId })
    let properties = try context.fetch(descriptor)
    XCTAssertNil(properties.first?.deletedAt)
    XCTAssertEqual(properties.first?.address, "Resurrected property")
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var handler: PropertySyncHandler!
  private var conflictResolver: ConflictResolver!

  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Test Helpers

  private func makeProperty(
    id: UUID = UUID(),
    address: String = "Test Address",
    unit: String? = nil,
    city: String = "",
    province: String = "",
    postalCode: String = "",
    country: String = "Canada",
    propertyType: PropertyType = .residential,
    ownedBy: UUID = UUID()
  ) -> Property {
    Property(
      id: id,
      address: address,
      unit: unit,
      city: city,
      province: province,
      postalCode: postalCode,
      country: country,
      propertyType: propertyType,
      ownedBy: ownedBy
    )
  }

  private func makePropertyDTO(
    id: UUID = UUID(),
    address: String = "Test Address",
    unit: String? = nil,
    city: String? = nil,
    province: String? = nil,
    postalCode: String? = nil,
    country: String? = nil,
    propertyType: String = "residential",
    ownedBy: UUID = UUID(),
    createdVia: String = "dispatch",
    deletedAt: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> PropertyDTO {
    PropertyDTO(
      id: id,
      address: address,
      unit: unit,
      city: city,
      province: province,
      postalCode: postalCode,
      country: country,
      propertyType: propertyType,
      ownedBy: ownedBy,
      createdVia: createdVia,
      deletedAt: deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
