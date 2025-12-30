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
        app.launch()
        
        // Locate the filter button
        let filterButton = app.buttons["AudienceFilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Audience Filter Button should exist on launch")
        
        // We expect to find these 3 states (rawValues)
        // Note: Using Set to be order-independent
        let expectedStates: Set<String> = ["all", "admin", "marketing"]
        var foundStates = Set<String>()
        
        // Cycle enough times to cover all cases + 1 to wrap around
        // (Assuming 3 cases, 4 taps should see everything and return to start)
        for _ in 0...4 {
            // Get current value (lens.rawValue)
            let currentValue = filterButton.value as? String
            
            if let value = currentValue {
                foundStates.insert(value)
                
                // Assert it's a valid known state
                XCTAssertTrue(expectedStates.contains(value), "Encountered unknown filter state: \(value)")
            }
            
            // Tap to cycle
            filterButton.tap()
        }
        
        // Assert we found all expected states
        XCTAssertTrue(foundStates.isSuperset(of: expectedStates), "Failed to find all expected filter states. Found: \(foundStates)")
    }
}
