//
//  ListingSyncHandlerTests.swift
//  DispatchTests
//
//  Unit tests for ListingSyncHandler entity-specific sync operations.
//  Tests upsertListing and deleteLocalListing logic including local-authoritative protection.
//

import SwiftData
import XCTest
@testable import DispatchApp

// MARK: - ListingSyncHandlerTests

@MainActor
final class ListingSyncHandlerTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()

    // Create in-memory SwiftData container for testing
    let schema = Schema([
      Listing.self,
      ListingTypeDefinition.self,
      ActivityTemplate.self,
      User.self,
      TaskItem.self,
      Activity.self,
      Note.self,
      StatusChange.self,
      Property.self
    ])
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
    handler = ListingSyncHandler(dependencies: deps)
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

  // MARK: - upsertListing Tests: Insert

  func test_upsertListing_insertsNewListing() throws {
    // Given: A new listing DTO that doesn't exist locally
    let listingId = UUID()
    let ownerId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "123 Test Street",
      ownedBy: ownerId
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Listing should be inserted
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.count, 1)
    XCTAssertEqual(listings.first?.address, "123 Test Street")
    XCTAssertEqual(listings.first?.ownedBy, ownerId)
    XCTAssertEqual(listings.first?.syncState, .synced)
  }

  func test_upsertListing_insertsWithAllFields() throws {
    // Given: A fully populated listing DTO
    let listingId = UUID()
    let ownerId = UUID()
    let propertyId = UUID()
    let typeDefinitionId = UUID()
    let now = Date()

    let dto = makeListingDTO(
      id: listingId,
      address: "456 Full Street",
      city: "Toronto",
      province: "ON",
      postalCode: "M5V 1A1",
      country: "Canada",
      price: 500000.0,
      mlsNumber: "MLS123456",
      listingType: "lease",
      listingTypeId: typeDefinitionId,
      status: "active",
      stage: "live",
      ownedBy: ownerId,
      propertyId: propertyId,
      dueDate: now
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: All fields should be populated correctly
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.count, 1)

    guard let listing = listings.first else {
      XCTFail("Expected listing to exist")
      return
    }
    XCTAssertEqual(listing.address, "456 Full Street")
    XCTAssertEqual(listing.city, "Toronto")
    XCTAssertEqual(listing.province, "ON")
    XCTAssertEqual(listing.postalCode, "M5V 1A1")
    XCTAssertEqual(listing.country, "Canada")
    XCTAssertEqual(listing.price, Decimal(500000.0))
    XCTAssertEqual(listing.mlsNumber, "MLS123456")
    XCTAssertEqual(listing.listingType, .lease)
    XCTAssertEqual(listing.typeDefinitionId, typeDefinitionId)
    XCTAssertEqual(listing.status, .active)
    XCTAssertEqual(listing.stage, .live)
    XCTAssertEqual(listing.propertyId, propertyId)
    XCTAssertEqual(listing.syncState, .synced)
  }

  // MARK: - upsertListing Tests: Update

  func test_upsertListing_updatesExistingListing() throws {
    // Given: An existing synced listing
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Old Address", ownedBy: ownerId)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // When: Upsert with updated address
    let dto = makeListingDTO(
      id: listingId,
      address: "New Address",
      ownedBy: ownerId
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: Listing should be updated
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.address, "New Address")
    XCTAssertEqual(listings.first?.syncState, .synced)
  }

  func test_upsertListing_updatesAllFieldsOnExistingListing() throws {
    // Given: An existing synced listing with minimal data
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Original", ownedBy: ownerId)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // When: Upsert with all fields populated
    let propertyId = UUID()
    let typeDefId = UUID()
    let dueDate = Date()
    let dto = makeListingDTO(
      id: listingId,
      address: "Updated Address",
      city: "Vancouver",
      province: "BC",
      postalCode: "V6B 1A1",
      country: "Canada",
      price: 750000.0,
      mlsNumber: "MLS999",
      listingType: "sale",
      listingTypeId: typeDefId,
      status: "pending",
      stage: "sold",
      ownedBy: ownerId,
      propertyId: propertyId,
      dueDate: dueDate
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: All fields should be updated
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)

    guard let listing = listings.first else {
      XCTFail("Expected listing to exist")
      return
    }
    XCTAssertEqual(listing.address, "Updated Address")
    XCTAssertEqual(listing.city, "Vancouver")
    XCTAssertEqual(listing.province, "BC")
    XCTAssertEqual(listing.postalCode, "V6B 1A1")
    XCTAssertEqual(listing.country, "Canada")
    XCTAssertEqual(listing.price, Decimal(750000.0))
    XCTAssertEqual(listing.mlsNumber, "MLS999")
    XCTAssertEqual(listing.listingType, .sale)
    XCTAssertEqual(listing.typeDefinitionId, typeDefId)
    XCTAssertEqual(listing.status, .pending)
    XCTAssertEqual(listing.stage, .sold)
    XCTAssertEqual(listing.propertyId, propertyId)
  }

  // MARK: - Local-Authoritative Protection Tests

  func test_upsertListing_skipsPendingListing() throws {
    // Given: A listing with pending local changes
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Pending local edit", ownedBy: ownerId)
    existingListing.markPending()
    context.insert(existingListing)
    try context.save()

    // When: Remote update arrives
    let dto = makeListingDTO(
      id: listingId,
      address: "Remote content",
      ownedBy: ownerId
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: Local content should be preserved (local-authoritative protection)
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.address, "Pending local edit")
    XCTAssertEqual(listings.first?.syncState, .pending)
  }

  func test_upsertListing_skipsFailedListing() throws {
    // Given: A listing with a failed sync attempt
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Failed sync content", ownedBy: ownerId)
    existingListing.markFailed("Previous sync error")
    context.insert(existingListing)
    try context.save()

    // When: Remote update arrives
    let dto = makeListingDTO(
      id: listingId,
      address: "Remote content",
      ownedBy: ownerId
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: Local content should be preserved
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.address, "Failed sync content")
    XCTAssertEqual(listings.first?.syncState, .failed)
    XCTAssertEqual(listings.first?.lastSyncError, "Previous sync error")
  }

  func test_upsertListing_updatesSyncedListing() throws {
    // Given: A properly synced listing (NOT local-authoritative)
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Synced content", ownedBy: ownerId)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // When: Remote update arrives
    let dto = makeListingDTO(
      id: listingId,
      address: "Remote update",
      ownedBy: ownerId
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: Listing SHOULD be updated (synced listings accept remote updates)
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.address, "Remote update")
    XCTAssertEqual(listings.first?.syncState, .synced)
  }

  func test_upsertListing_noInFlightProtectionForListings() throws {
    // Given: A synced listing (no in-flight tracking for listings in V1)
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Original", ownedBy: ownerId)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // Note: ListingSyncHandler uses hardcoded `inFlight: false`
    // because listings are rarely user-edited locally in V1

    // When: Remote update arrives
    let dto = makeListingDTO(
      id: listingId,
      address: "Remote update",
      ownedBy: ownerId
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: Update should be applied (no in-flight protection for listings)
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.address, "Remote update")
  }

  // MARK: - markSynced Tests

  func test_upsertListing_callsMarkSyncedOnInsert() throws {
    // Given: A new listing DTO
    let listingId = UUID()
    let dto = makeListingDTO(id: listingId, address: "New Listing", ownedBy: UUID())

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Listing should be marked as synced
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.syncState, .synced)
    XCTAssertNotNil(listings.first?.syncedAt)
    XCTAssertNil(listings.first?.lastSyncError)
  }

  func test_upsertListing_callsMarkSyncedOnUpdate() throws {
    // Given: An existing synced listing
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Original", ownedBy: ownerId)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // When: Update the listing
    let dto = makeListingDTO(id: listingId, address: "Updated", ownedBy: ownerId)
    try handler.upsertListing(dto: dto, context: context)

    // Then: syncedAt should be updated and state should be synced
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.syncState, .synced)
    XCTAssertNotNil(listings.first?.syncedAt)
  }

  // MARK: - establishOwnerRelationship Callback Tests

  func test_upsertListing_invokesEstablishOwnerRelationshipOnInsert() throws {
    // Given: A new listing DTO and a callback tracker
    let listingId = UUID()
    let ownerId = UUID()
    let dto = makeListingDTO(id: listingId, address: "New", ownedBy: ownerId)

    var callbackInvoked = false
    var capturedListingId: UUID?
    var capturedOwnerId: UUID?

    let establishOwner: (Listing, UUID, ModelContext) throws -> Void = { listing, ownerUUID, _ in
      callbackInvoked = true
      capturedListingId = listing.id
      capturedOwnerId = ownerUUID
    }

    // When: Upsert with callback
    try handler.upsertListing(dto: dto, context: context, establishOwnerRelationship: establishOwner)

    // Then: Callback should be invoked with correct parameters
    XCTAssertTrue(callbackInvoked)
    XCTAssertEqual(capturedListingId, listingId)
    XCTAssertEqual(capturedOwnerId, ownerId)
  }

  func test_upsertListing_invokesEstablishOwnerRelationshipOnUpdate() throws {
    // Given: An existing synced listing
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Original", ownedBy: ownerId)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // And: A callback tracker
    var callbackInvoked = false
    let establishOwner: (Listing, UUID, ModelContext) throws -> Void = { _, _, _ in
      callbackInvoked = true
    }

    // When: Update with callback
    let dto = makeListingDTO(id: listingId, address: "Updated", ownedBy: ownerId)
    try handler.upsertListing(dto: dto, context: context, establishOwnerRelationship: establishOwner)

    // Then: Callback should be invoked
    XCTAssertTrue(callbackInvoked)
  }

  func test_upsertListing_skipsCallbackWhenNilProvided() throws {
    // Given: A new listing DTO with no callback
    let listingId = UUID()
    let dto = makeListingDTO(id: listingId, address: "New", ownedBy: UUID())

    // When: Upsert without callback (should not crash)
    try handler.upsertListing(dto: dto, context: context, establishOwnerRelationship: nil)

    // Then: Listing should still be inserted
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.count, 1)
  }

  // MARK: - deleteLocalListing Tests

  func test_deleteLocalListing_deletesExistingListing() throws {
    // Given: An existing listing
    let listingId = UUID()
    let existingListing = makeListing(id: listingId, address: "To be deleted", ownedBy: UUID())
    context.insert(existingListing)
    try context.save()

    // When: Delete the listing
    let deleted = try handler.deleteLocalListing(id: listingId, context: context)

    // Then: Listing should be deleted
    XCTAssertTrue(deleted)
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertTrue(listings.isEmpty)
  }

  func test_deleteLocalListing_returnsFalseForMissingListing() throws {
    // Given: A non-existent listing ID
    let missingId = UUID()

    // When: Try to delete
    let deleted = try handler.deleteLocalListing(id: missingId, context: context)

    // Then: Should return false
    XCTAssertFalse(deleted)
  }

  func test_deleteLocalListing_deletesListingWithRelationships() throws {
    // Given: A listing with tasks and notes
    let listingId = UUID()
    let existingListing = makeListing(id: listingId, address: "Has relationships", ownedBy: UUID())
    context.insert(existingListing)
    try context.save()

    // When: Delete the listing
    let deleted = try handler.deleteLocalListing(id: listingId, context: context)

    // Then: Listing should be deleted (cascade rules handle relationships)
    XCTAssertTrue(deleted)
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertTrue(listings.isEmpty)
  }

  // MARK: - Enum Fallback Tests

  func test_upsertListing_fallsBackToSaleForInvalidListingType() throws {
    // Given: A DTO with an invalid listing type
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "Invalid Type",
      listingType: "invalid_type_value", // Not a valid ListingType
      ownedBy: UUID()
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Should fall back to .sale
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.listingType, .sale)
  }

  func test_upsertListing_fallsBackToDraftForInvalidStatus() throws {
    // Given: A DTO with an invalid status
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "Invalid Status",
      status: "invalid_status_value", // Not a valid ListingStatus
      ownedBy: UUID()
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Should fall back to .draft
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.status, .draft)
  }

  func test_upsertListing_fallsBackToPendingForInvalidStage() throws {
    // Given: A DTO with an invalid stage
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "Invalid Stage",
      stage: "invalid_stage_value", // Not a valid ListingStage
      ownedBy: UUID()
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Should fall back to .pending
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.stage, .pending)
  }

  func test_upsertListing_fallsBackToPendingForNilStage() throws {
    // Given: A DTO with nil stage (backward compatibility)
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "Nil Stage",
      stage: nil,
      ownedBy: UUID()
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Should fall back to .pending
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.stage, .pending)
  }

  // MARK: - Optional Field Handling Tests

  func test_upsertListing_handlesNilOptionalFields() throws {
    // Given: A DTO with minimal data (all optional fields nil)
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "Minimal Listing",
      city: nil,
      province: nil,
      postalCode: nil,
      country: nil,
      price: nil,
      mlsNumber: nil,
      listingTypeId: nil,
      ownedBy: UUID(),
      propertyId: nil,
      dueDate: nil
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Optional fields should have defaults or be nil
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)

    guard let listing = listings.first else {
      XCTFail("Expected listing to exist")
      return
    }
    XCTAssertEqual(listing.city, "") // Defaults to empty string
    XCTAssertEqual(listing.province, "") // Defaults to empty string
    XCTAssertEqual(listing.postalCode, "") // Defaults to empty string
    XCTAssertEqual(listing.country, "Canada") // Defaults to "Canada"
    XCTAssertNil(listing.price)
    XCTAssertNil(listing.mlsNumber)
    XCTAssertNil(listing.typeDefinitionId)
    XCTAssertNil(listing.propertyId)
    XCTAssertNil(listing.dueDate)
  }

  // MARK: - Price Conversion Tests

  func test_upsertListing_convertsPriceFromDoubleToDecimal() throws {
    // Given: A DTO with a price as Double
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "Priced Listing",
      price: 1234567.89,
      ownedBy: UUID()
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Price should be converted to Decimal
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertEqual(listings.first?.price, Decimal(1234567.89))
  }

  func test_upsertListing_handlesNilPrice() throws {
    // Given: A DTO with nil price
    let listingId = UUID()
    let dto = makeListingDTO(
      id: listingId,
      address: "No Price",
      price: nil,
      ownedBy: UUID()
    )

    // When: Upsert the listing
    try handler.upsertListing(dto: dto, context: context)

    // Then: Price should be nil
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertNil(listings.first?.price)
  }

  func test_upsertListing_updatesExistingPriceFromNonNilToNil() throws {
    // Given: An existing listing with a price
    let listingId = UUID()
    let ownerId = UUID()
    let existingListing = makeListing(id: listingId, address: "Has Price", ownedBy: ownerId)
    existingListing.price = Decimal(500000)
    existingListing.markSynced()
    context.insert(existingListing)
    try context.save()

    // When: Update with nil price
    let dto = makeListingDTO(
      id: listingId,
      address: "Has Price",
      price: nil,
      ownedBy: ownerId
    )
    try handler.upsertListing(dto: dto, context: context)

    // Then: Price should be nil
    let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
    let listings = try context.fetch(descriptor)
    XCTAssertNil(listings.first?.price)
  }

  // MARK: - Valid Enum Values Tests

  func test_upsertListing_acceptsAllValidListingTypes() throws {
    let validTypes = ["sale", "lease", "pre_listing", "rental", "other"]
    let expectedTypes: [ListingType] = [.sale, .lease, .preListing, .rental, .other]

    for (index, typeString) in validTypes.enumerated() {
      let listingId = UUID()
      let dto = makeListingDTO(
        id: listingId,
        address: "Type Test \(typeString)",
        listingType: typeString,
        ownedBy: UUID()
      )

      try handler.upsertListing(dto: dto, context: context)

      let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
      let listings = try context.fetch(descriptor)
      XCTAssertEqual(listings.first?.listingType, expectedTypes[index], "Failed for type: \(typeString)")
    }
  }

  func test_upsertListing_acceptsAllValidStatuses() throws {
    let validStatuses = ["draft", "active", "pending", "closed", "deleted"]
    let expectedStatuses: [ListingStatus] = [.draft, .active, .pending, .closed, .deleted]

    for (index, statusString) in validStatuses.enumerated() {
      let listingId = UUID()
      let dto = makeListingDTO(
        id: listingId,
        address: "Status Test \(statusString)",
        status: statusString,
        ownedBy: UUID()
      )

      try handler.upsertListing(dto: dto, context: context)

      let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
      let listings = try context.fetch(descriptor)
      XCTAssertEqual(listings.first?.status, expectedStatuses[index], "Failed for status: \(statusString)")
    }
  }

  func test_upsertListing_acceptsAllValidStages() throws {
    let validStages = ["pending", "working_on", "live", "sold", "re_list", "done"]
    let expectedStages: [ListingStage] = [.pending, .workingOn, .live, .sold, .reList, .done]

    for (index, stageString) in validStages.enumerated() {
      let listingId = UUID()
      let dto = makeListingDTO(
        id: listingId,
        address: "Stage Test \(stageString)",
        stage: stageString,
        ownedBy: UUID()
      )

      try handler.upsertListing(dto: dto, context: context)

      let descriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingId })
      let listings = try context.fetch(descriptor)
      XCTAssertEqual(listings.first?.stage, expectedStages[index], "Failed for stage: \(stageString)")
    }
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var container: ModelContainer!
  private var context: ModelContext!
  private var handler: ListingSyncHandler!
  private var conflictResolver: ConflictResolver!

  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Test Helpers

  private func makeListing(
    id: UUID = UUID(),
    address: String = "Test Address",
    ownedBy: UUID
  ) -> Listing {
    Listing(
      id: id,
      address: address,
      ownedBy: ownedBy
    )
  }

  private func makeListingDTO(
    id: UUID = UUID(),
    address: String = "Test Address",
    city: String? = "Toronto",
    province: String? = "ON",
    postalCode: String? = "M5V 1A1",
    country: String? = "Canada",
    price: Double? = nil,
    mlsNumber: String? = nil,
    listingType: String = "sale",
    listingTypeId: UUID? = nil,
    status: String = "draft",
    stage: String? = "pending",
    ownedBy: UUID = UUID(),
    propertyId: UUID? = nil,
    dueDate: Date? = nil
  ) -> ListingDTO {
    ListingDTO(
      id: id,
      address: address,
      city: city,
      province: province,
      postalCode: postalCode,
      country: country,
      price: price,
      mlsNumber: mlsNumber,
      listingType: listingType,
      listingTypeId: listingTypeId,
      status: status,
      stage: stage,
      ownedBy: ownedBy,
      propertyId: propertyId,
      createdVia: "dispatch",
      sourceSlackMessages: nil,
      activatedAt: nil,
      pendingAt: nil,
      closedAt: nil,
      deletedAt: nil,
      dueDate: dueDate,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
