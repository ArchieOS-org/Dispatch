//
//  AppStateTests.swift
//  DispatchTests
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI
import XCTest
@testable import DispatchApp

@MainActor
class AppStateTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    // Use shared managers for now since they are singletons,
    // ideally mock them but for this iteration we test the logic connections.
    appState = AppState()
  }

  // MARK: - Router Tests

  func test_dispatch_navigate_updatesRouterPath() {
    let route = AppRoute.listing(UUID())
    appState.dispatch(.navigate(route))

    // Legacy .navigate command writes to phonePath (iPhone single-stack navigation)
    XCTAssertEqual(appState.router.phonePath.count, 1)
    // Note: checking deep equality on path is tricky in SwiftUI,
    // but verifying count > 0 confirms append happened.
  }

  func test_dispatch_popToRoot_clearsRouterPath() {
    let route = AppRoute.listing(UUID())
    appState.dispatch(.navigate(route))
    // Legacy .navigate writes to phonePath
    XCTAssertFalse(appState.router.phonePath.isEmpty)

    // Use phonePopToRoot to clear phonePath (matches the navigation model)
    appState.dispatch(.phonePopToRoot)
    XCTAssertTrue(appState.router.phonePath.isEmpty)
  }

  func test_router_selectSameTab_popsToRoot() {
    appState.router.navigate(to: .listing(UUID()))
    appState.router.setSelectedDestination(.tab(.workspace))

    // Select same tab via user action (should pop to root)
    appState.router.userSelectTab(.workspace)

    let currentPath = appState.router.paths[appState.router.selectedDestination] ?? []
    XCTAssertTrue(currentPath.isEmpty)
  }

  func test_router_switchTab_maintainsPerTabPaths() {
    // Start at workspace
    appState.router.setSelectedDestination(.tab(.workspace))
    appState.router.navigate(to: .listing(UUID()))

    // Switch to listings - path is per-destination, so workspace path stays
    appState.router.setSelectedTab(.listings)

    XCTAssertEqual(appState.router.selectedTab, .listings)
    // Listings path should be empty (new destination)
    let listingsPath = appState.router.paths[.tab(.listings)] ?? []
    XCTAssertTrue(listingsPath.isEmpty)
  }

  // MARK: - Command Tests

  func test_dispatch_openSearch_setsOverlayState() {
    appState.dispatch(.openSearch(initialText: "test"))

    if case .search(let text) = appState.overlayState {
      XCTAssertEqual(text, "test")
    } else {
      XCTFail("Overlay state should be search")
    }
  }

  // MARK: Private

  private var appState = AppState()

}
