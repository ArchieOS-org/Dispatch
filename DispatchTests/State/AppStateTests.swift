//
//  AppStateTests.swift
//  DispatchTests
//
//  Created for Dispatch Architecture Unification
//

import XCTest
@testable import Dispatch

@MainActor
class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        // Use shared managers for now since they are singletons, 
        // ideally mock them but for this iteration we test the logic connections.
        appState = AppState()
    }
    
    // MARK: - Router Tests
    
    func test_dispatch_navigate_updatesRouterPath() {
        let destination = Destination.listing(UUID())
        appState.dispatch(.navigate(destination))
        
        XCTAssertEqual(appState.router.path.count, 1)
        // Note: checking deep equality on path is tricky in SwiftUI, 
        // but verifying count > 0 confirms append happened.
    }
    
    func test_dispatch_popToRoot_clearsRouterPath() {
        let destination = Destination.listing(UUID())
        appState.dispatch(.navigate(destination))
        XCTAssertFalse(appState.router.path.isEmpty)
        
        appState.dispatch(.popToRoot)
        XCTAssertTrue(appState.router.path.isEmpty)
    }
    
    func test_router_selectSameTab_popsToRoot() {
        appState.router.navigate(to: .listing(UUID()))
        appState.router.selectedTab = .workspace
        
        // Select same tab
        appState.router.selectTab(.workspace)
        
        XCTAssertTrue(appState.router.path.isEmpty)
    }
    
    func test_router_switchTab_clearsPath() {
        // Start at workspace
        appState.router.selectedTab = .workspace
        appState.router.navigate(to: .listing(UUID()))
        
        // Switch to listings
        appState.router.selectTab(.listings)
        
        XCTAssertEqual(appState.router.selectedTab, .listings)
        XCTAssertTrue(appState.router.path.isEmpty)
    }
    
    // MARK: - Command Tests
    
    func test_dispatch_openSearch_setsOverlayState() {
        appState.dispatch(.openSearch(initialText: "test"))
        
        if case .quickFind(let text) = appState.overlayState {
            XCTAssertEqual(text, "test")
        } else {
            XCTFail("Overlay state should be quickFind")
        }
    }
}
