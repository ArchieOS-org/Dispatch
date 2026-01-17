//
//  FilterUITests.swift
//  DispatchUITests
//
//  Created by Gemini on 2025-12-29.
//

import XCTest

final class FilterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies that the Audience Filter button cycles through all expected states.
    /// Invariants:
    /// 1. Button exists.
    /// 2. Button has valid initial state.
    /// 3. Cycling the button reveals "all", "admin", "marketing" states.
    /// 4. No unknown states are encountered.
    @MainActor
    func testAudienceFilterCycle() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()

        // On iPhone, app launches to MenuPageView - navigate to Workspace first
        // Find "My Workspace" menu item and tap it
        let workspaceButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "My Workspace")
        ).element
        if workspaceButton.waitForExistence(timeout: 5) {
            workspaceButton.tap()
        }

        // Locate the filter button (now visible on Workspace screen)
        let filterButton = app.buttons["AudienceFilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Audience Filter Button should exist on Workspace screen")
        
        // Helper to verify current state
        func verifyState(_ lens: String, icon: String) {
            guard let rawValue = filterButton.value as? String else {
                XCTFail("Filter button value should be a string")
                return
            }
            // Format is "lens|icon"
            let parts = rawValue.split(separator: "|")
            XCTAssertEqual(parts.count, 2, "Accessibility value should be 'lens|icon'")
            
            let currentLens = String(parts[0])
            let currentIcon = String(parts[1])
            
            XCTAssertEqual(currentLens, lens, "Lens verification failed")
            XCTAssertEqual(currentIcon, icon, "Icon verification failed")
        }
        
        // 1. Initial State: All
        verifyState("all", icon: "line.3.horizontal.decrease")
        
        // 2. Cycle to Admin
        filterButton.tap()
        verifyState("admin", icon: "a.circle")
        
        // 3. Cycle to Marketing
        filterButton.tap()
        verifyState("marketing", icon: "m.circle")
        
        // 4. Cycle back to All
        filterButton.tap()
        verifyState("all", icon: "line.3.horizontal.decrease")
    }
}
