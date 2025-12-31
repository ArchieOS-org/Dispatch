//
//  SyncRelationshipTests.swift
//  DispatchTests
//
//  Created for Phase 1.3: Sync Logic Verification
//  Proves that Listing-User relationships are resolved correctly regardless of sync order.
//

import XCTest
import SwiftData
@testable import DispatchApp

@MainActor
final class SyncRelationshipTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var syncManager: SyncManager!

    override func setUp() async throws {
        // Use in-memory container for speed and isolation
        let schema = Schema([User.self, Listing.self, TaskItem.self, Activity.self, Note.self, StatusChange.self, ClaimEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        
        // Initialize SyncManager with this container
        syncManager = SyncManager()
        syncManager.configure(with: container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        syncManager = nil
    }

    // MARK: - Tests

    /// Invariant: User arrives -> Listing arrives -> Relationship Established
    func testUserArrives_ThenListingArrives_RelationshipResolves() async throws {
        // 1. Insert User
        let userId = UUID()
        let user = User(id: userId, name: "Test User", email: "test@example.com", userType: .realtor)
        context.insert(user)
        try context.save()

        // 2. Insert Listing (simulating sync down)
        let listingId = UUID()
        let listingDTO = ListingDTO(
            id: listingId,
            address: "123 Main St",
            city: nil, province: nil, postalCode: nil, country: nil, price: nil, mlsNumber: nil,
            listingType: "sale", status: "active",
            ownedBy: userId, // Points to user
            createdVia: "dispatch", sourceSlackMessages: nil,
            activatedAt: nil, pendingAt: nil, closedAt: nil, deletedAt: nil, dueDate: nil,
            createdAt: Date(), updatedAt: Date()
        )
        
        // Call internal sync method (simulated via reflection or just direct access if internal)
        // Since we can't easily access private methods from tests without @testable import, 
        // we'll rely on the public surface or internal access provided by @testable.
        // Assuming upsertListing is private, we might need to expose it or test via a public entry point if possible.
        // HOWEVER, for this "Jobs-standard" proof, we want to test the *logic*. 
        // If upsertListing is private, we can't call it. 
        // Strategy: Use a helper extension in the test target or assume @testable access allows it.
        // 'upsertListing' is private in SyncManager.
        // We will need to make it internal for testing or add a test hook.
        // For now, let's assume we'll make it internal in the implementation step.
        // If we can't, we'd simulate the full sync, but that needs mocked Supabase.
        // BETTER: We will reproduce the failure by manually creating the state that upsertListing WOULD create,
        // then running the reconciliation function (which we also need to make internal).
        
        // Actually, let's modify SyncManager to be testable. 
        // Changing private to internal for `upsertListing` and `reconcileListingRelationships` is acceptable for white-box testing.
        
        // Replicating typical upsert logic manually if we can't call it yet:
        let listing = listingDTO.toModel()
        context.insert(listing) 
        // CRITICAL: The bug is that we insert but don't link. 
        // So `listing.owner` is nil here.
        try context.save()
        
        XCTAssertNil(listing.owner, "Pre-condition: owner should be nil before fix")
        
        // 3. Run Reconciliation (the fix)
        try await syncManager.reconcileListingRelationships(context: context)
        
        // 4. Assert
        XCTAssertNotNil(listing.owner, "Relationship should be resolved after reconciliation")
        XCTAssertEqual(listing.owner?.id, userId, "Should link to the correct user")
    }

    /// Invariant: Listing arrives -> User arrives -> Relationship Resolves
    func testListingArrivesSynced_ThenUserArrives_RelationshipResolves() async throws {
        // 1. Insert Listing first (orphaned)
        let userId = UUID()
        let listingId = UUID()
        let listing = Listing(
            id: listingId,
            address: "456 Orphan Way",
            ownedBy: userId // Points to unknown user
        )
        context.insert(listing)
        try context.save()
        
        XCTAssertNil(listing.owner)

        // 2. Insert User later
        let user = User(id: userId, name: "Late Arrival", email: "late@example.com", userType: .realtor)
        context.insert(user)
        try context.save()
        
        // 3. Run Reconciliation
        try await syncManager.reconcileListingRelationships(context: context)
        
        // 4. Assert
        XCTAssertNotNil(listing.owner, "Orphaned listing should find its parent")
        XCTAssertEqual(listing.owner?.name, "Late Arrival")
    }
    
    /// Regression Guard: Valid links are not clobbered
    func testReconciliation_LeavesValidLinksIntact() async throws {
        // 1. Setup valid relationship
        let userId = UUID()
        let user = User(id: userId, name: "Existing Owner", email: "exist@example.com", userType: .realtor)
        let listing = Listing(id: UUID(), address: "789 Safe St", ownedBy: userId)
        listing.owner = user // Manually linked
        
        context.insert(user)
        context.insert(listing)
        try context.save()
        
        XCTAssertNotNil(listing.owner)
        
        // 2. Run Reconciliation
        try await syncManager.reconcileListingRelationships(context: context)
        
        // 3. Assert
        XCTAssertNotNil(listing.owner)
        XCTAssertEqual(listing.owner?.id, userId) 
        // Ensure it didn't somehow nil it out
    }
}
