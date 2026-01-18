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

// swiftlint:disable force_unwrapping

import SwiftData
import SwiftUI
import XCTest
@testable import DispatchApp

final class PreviewInfrastructureTests: XCTestCase {

  @MainActor
  func testListingDetailView_isolation_and_stability() async throws {
    // Skip on macOS: SwiftData container timing differs with NSHostingController
    // causing the content closure to evaluate before the container is ready.
    // This test validates iOS preview infrastructure which is the primary use case.
    #if os(macOS)
    throw XCTSkip("Preview infrastructure test is iOS-only (SwiftData timing differs on macOS)")
    #endif

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
    #if os(macOS)
    let vc = NSHostingController(rootView: shell)
    // 3. Force Lifecycle & Layout
    _ = vc.view
    vc.view.layout()
    #else
    let vc = UIHostingController(rootView: shell)
    // 3. Force Lifecycle & Layout
    _ = vc.view
    vc.view.setNeedsLayout()
    vc.view.layoutIfNeeded()
    #endif

    // Allow a runloop cycle for async tasks (like .task modifier) to start
    let expectation = XCTestExpectation(description: "View Lifecycle")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }

    // 4. Assert
    await fulfillment(of: [expectation], timeout: 1.0)

    // Assert Strict Isolation
    XCTAssertEqual(spySyncManager.mode, .preview, "SyncManager should be in preview mode")
    XCTAssertEqual(
      spySyncManager._telemetry_syncRequests,
      0,
      "FATAL: View triggered sync in preview mode! Side effect detected."
    )

    // 5. Cleanup
    await spySyncManager.shutdown()
  }
}
