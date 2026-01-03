//
//  StageCardsTests.swift
//  DispatchTests
//
//  Tests for stage cards feature: counts computation, badge visibility, route restoration.
//

import Testing
import Foundation
@testable import DispatchApp

// MARK: - Stage Counts Tests

struct StageCountsTests {

    @Test("stageCounts excludes deleted listings")
    func testStageCountsExcludesDeleted() {
        // Create mock listings with different stages and statuses
        let listing1 = Listing(
            address: "123 Main St",
            city: "Test",
            state: "CA",
            zipCode: "12345",
            stage: .live
        )
        listing1.status = .active

        let listing2 = Listing(
            address: "456 Oak Ave",
            city: "Test",
            state: "CA",
            zipCode: "12345",
            stage: .live
        )
        listing2.status = .deleted // Should not count

        let listing3 = Listing(
            address: "789 Pine Rd",
            city: "Test",
            state: "CA",
            zipCode: "12345",
            stage: .sold
        )
        listing3.status = .active

        let listings = [listing1, listing2, listing3]
        let counts = listings.stageCounts()

        // Use default: for dictionary access - counts[.live] returns Int?
        #expect(counts[.live, default: 0] == 1) // Not 2 (deleted excluded)
        #expect(counts[.sold, default: 0] == 1)
        #expect(counts[.pending, default: 0] == 0) // No pending listings
    }

    @Test("stageCounts counts all stages correctly")
    func testStageCountsAllStages() {
        var listings: [Listing] = []

        // Create listings for each stage
        for stage in ListingStage.allCases {
            let listing = Listing(
                address: "Address for \(stage.displayName)",
                city: "Test",
                state: "CA",
                zipCode: "12345",
                stage: stage
            )
            listing.status = .active
            listings.append(listing)
        }

        // Add an extra live listing
        let extraLive = Listing(
            address: "Extra Live",
            city: "Test",
            state: "CA",
            zipCode: "12345",
            stage: .live
        )
        extraLive.status = .active
        listings.append(extraLive)

        let counts = listings.stageCounts()

        #expect(counts[.live, default: 0] == 2) // Extra live + one from loop
        #expect(counts[.pending, default: 0] == 1)
        #expect(counts[.workingOn, default: 0] == 1)
        #expect(counts[.sold, default: 0] == 1)
        #expect(counts[.reList, default: 0] == 1)
        #expect(counts[.done, default: 0] == 1)
    }

    @Test("stageCounts handles empty array")
    func testStageCountsEmpty() {
        let listings: [Listing] = []
        let counts = listings.stageCounts()

        #expect(counts.isEmpty)
        #expect(counts[.live, default: 0] == 0)
    }
}

// MARK: - Badge Visibility Tests

struct StageBadgeRuleTests {

    @Test("Done stage always hides badge")
    func testDoneStageHidesBadge() {
        // Done stage: always hidden regardless of count
        #expect(StageBadgeRule.shouldHide(stage: .done, count: 0) == true)
        #expect(StageBadgeRule.shouldHide(stage: .done, count: 5) == true)
        #expect(StageBadgeRule.shouldHide(stage: .done, count: 100) == true)
    }

    @Test("Zero count hides badge for non-done stages")
    func testZeroCountHidesBadge() {
        // Zero count: hidden for all non-done stages
        #expect(StageBadgeRule.shouldHide(stage: .live, count: 0) == true)
        #expect(StageBadgeRule.shouldHide(stage: .pending, count: 0) == true)
        #expect(StageBadgeRule.shouldHide(stage: .workingOn, count: 0) == true)
        #expect(StageBadgeRule.shouldHide(stage: .sold, count: 0) == true)
        #expect(StageBadgeRule.shouldHide(stage: .reList, count: 0) == true)
    }

    @Test("Non-zero count shows badge for non-done stages")
    func testNonZeroCountShowsBadge() {
        // Non-zero, non-done: visible
        #expect(StageBadgeRule.shouldHide(stage: .live, count: 1) == false)
        #expect(StageBadgeRule.shouldHide(stage: .live, count: 3) == false)
        #expect(StageBadgeRule.shouldHide(stage: .pending, count: 10) == false)
        #expect(StageBadgeRule.shouldHide(stage: .workingOn, count: 5) == false)
        #expect(StageBadgeRule.shouldHide(stage: .sold, count: 2) == false)
        #expect(StageBadgeRule.shouldHide(stage: .reList, count: 1) == false)
    }
}

// MARK: - Route Restoration Tests

struct RouteRestorationTests {

    @Test("Route encodes and decodes correctly for restoration")
    func testRouteRestoration() throws {
        let route = Route.stagedListings(.workingOn)

        let encoded = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(Route.self, from: encoded)

        #expect(route == decoded)
    }

    @Test("Route encodes and decodes all stages correctly")
    func testRouteRestorationAllStages() throws {
        for stage in ListingStage.allCases {
            let route = Route.stagedListings(stage)

            let encoded = try JSONEncoder().encode(route)
            let decoded = try JSONDecoder().decode(Route.self, from: encoded)

            #expect(route == decoded)
        }
    }

    @Test("Route is Hashable")
    func testRouteHashable() {
        let route1 = Route.stagedListings(.live)
        let route2 = Route.stagedListings(.live)
        let route3 = Route.stagedListings(.sold)

        #expect(route1 == route2)
        #expect(route1 != route3)

        // Can be used in a Set
        var routeSet = Set<Route>()
        routeSet.insert(route1)
        routeSet.insert(route2) // Duplicate, should not increase count
        routeSet.insert(route3)

        #expect(routeSet.count == 2)
    }
}
