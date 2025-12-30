//
//  PreviewInfrastructureTests.swift
//  DispatchTests
//
//  Jobs-Standard Verification for Preview Infrastructure.
//  Ensures:
//  1. No Crashes (Stability)
//  2. No Side Effects (Isolation)
//  3. Full Lifecycle Execution (Reliability)
//

import XCTest
import SwiftUI
import SwiftData
@testable import DispatchApp

final class PreviewInfrastructureTests: XCTestCase {
    
    @MainActor
    func testListingDetailView_isolation_and_stability() async {
        // 1. Arrange with Test Spies
        let spySyncManager = SyncManager(mode: .preview)
        
        // Use the canonical shell exactly as the preview does
        let shell = PreviewShell(
            syncManager: spySyncManager,
            setup: { context in PreviewDataFactory.seed(context) }
        ) { context in
            // Simulate real usage: fetch deterministic data
            let listingID = PreviewDataFactory.listingID
            let listingDescriptor = FetchDescriptor<Listing>(predicate: #Predicate { $0.id == listingID })
            let listing = try! context.fetch(listingDescriptor).first!
            
            ListingDetailView(
                listing: listing,
                userLookup: { _ in nil } // Lookup logic is tested separately; we just need it not to crash
            )
        }
        
        // 2. Act: Host it
        let vc = UIHostingController(rootView: shell)
        
        // 3. Force Lifecycle & Layout
        // This ensures .task, .onAppear, and initial layout passes actually run
        _ = vc.view
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        
        // Allow a runloop cycle for async tasks (like .task modifier) to start
        let expectation = XCTestExpectation(description: "View Lifecycle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        // 4. Assert
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert Strict Isolation
        XCTAssertEqual(spySyncManager.mode, .preview, "SyncManager should be in preview mode")
        XCTAssertEqual(spySyncManager._telemetry_syncRequests, 0, "FATAL: View triggered sync in preview mode! Side effect detected.")
        
        // 5. Cleanup
        await spySyncManager.shutdown()
    }
}
