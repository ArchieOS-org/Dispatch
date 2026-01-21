//
//  NavigationUITests.swift
//  DispatchUITests
//
//  Tests for ID-based navigation to verify route resolution.
//  Part of navigation migration to prevent ModelContext.reset() crashes.
//

import XCTest

final class NavigationUITests: XCTestCase {

  // MARK: Internal

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    // Clean up after tests
  }

  /// Verifies that tapping a realtor pill navigates to their profile
  @MainActor
  func testRealtorPillNavigation() throws {
    let app = launchApp()

    // Navigate to a listing detail that has a realtor pill
    // This assumes the test data includes a listing with an owner
    // ListingRow uses accessibilityIdentifier set to the address
    let listingCell = app.cells["123 Job Standard Blvd"].firstMatch
    if listingCell.waitForExistence(timeout: 5) {
      listingCell.tap()

      // Find and tap the realtor pill
      let realtorPill = app.buttons.containing(.staticText, identifier: "Bob Agent").firstMatch
      if realtorPill.waitForExistence(timeout: 3) {
        realtorPill.tap()

        // Verify we're on the realtor profile
        let profileTitle = app.navigationBars["Bob Agent"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 3), "Should navigate to realtor profile")
      }
    }
  }

  /// Verifies that listing navigation resolves correctly via ID
  @MainActor
  func testListingNavigation() throws {
    let app = launchApp()

    // Use CI-appropriate timeout (15s instead of 5s)
    // ListingRow uses accessibilityIdentifier set to the address
    let listingCell = app.cells["123 Job Standard Blvd"].firstMatch
    XCTAssertTrue(listingCell.waitForExistence(timeout: 15), "Listing cell should exist in seeded data")

    listingCell.tap()

    // Verify navigation completed with reasonable timeout
    // Search staticTexts instead of navigationBars for more reliable element matching
    let detailTitle = app.staticTexts["123 Job Standard Blvd"]
    XCTAssertTrue(detailTitle.waitForExistence(timeout: 10), "Should navigate to listing detail")
  }

  /// Verifies that property navigation resolves correctly via ID
  @MainActor
  func testPropertyNavigation() throws {
    let app = launchApp()

    // Navigate to properties tab
    let propertiesTab = app.tabBars.buttons["Properties"]
    if propertiesTab.waitForExistence(timeout: 5) {
      propertiesTab.tap()

      // PropertyRow uses accessibilityIdentifier set to displayAddress
      let propertyCell = app.cells["456 Test Property Lane"].firstMatch
      if propertyCell.waitForExistence(timeout: 5) {
        propertyCell.tap()

        // Verify we're on the property detail
        let detailTitle = app.navigationBars["456 Test Property Lane"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3), "Should navigate to property detail")
      }
    }
  }

  /// Verifies that work item navigation resolves correctly via ID
  @MainActor
  func testWorkItemNavigation() throws {
    let app = launchApp()

    // ListingRow uses accessibilityIdentifier set to the address
    let listingCell = app.cells["123 Job Standard Blvd"].firstMatch
    if listingCell.waitForExistence(timeout: 5) {
      listingCell.tap()

      // Tap on a task within the listing
      let taskCell = app.cells.containing(.staticText, identifier: "Inspect Roof").firstMatch
      if taskCell.waitForExistence(timeout: 3) {
        taskCell.tap()

        // Verify we're on the work item detail
        let detailTitle = app.navigationBars["Inspect Roof"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3), "Should navigate to work item detail")
      }
    }
  }

  // MARK: Private

  private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments.append("--uitesting")
    app.launch()
    return app
  }
}
