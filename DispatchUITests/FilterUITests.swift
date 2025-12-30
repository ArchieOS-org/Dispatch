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
    @MainActor
    func testAudienceFilterCycle() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Locate the filter button
        let filterButton = app.buttons["AudienceFilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Audience Filter Button should exist on launch")
        
        // Expected mapping: Lens -> Icon Name
        let expectedIcons: [String: String] = [
            "all": "line.3.horizontal.decrease",
            "admin": "shield.lefthalf.filled",
            "marketing": "megaphone.fill"
        ]
        
        var foundStates = Set<String>()
        
        // Cycle enough times to cover all cases + 1 to wrap around
        for _ in 0...4 {
            guard let rawValue = filterButton.value as? String else {
                XCTFail("Filter button value should be a string")
                return
            }
            
            // Format is "lens|icon"
            let parts = rawValue.split(separator: "|")
            XCTAssertEqual(parts.count, 2, "Accessibility value should be 'lens|icon'")
            
            let lens = String(parts[0])
            let icon = String(parts[1])
            
            // 1. Verify we know this lens
            XCTAssertNotNil(expectedIcons[lens], "Unknown lens state: \(lens)")
            
            // 2. Verify the icon matches the specific spec (Regression Lock)
            XCTAssertEqual(expectedIcons[lens], icon, "Icon mismatch for lens '\(lens)'")
            
            foundStates.insert(lens)
            
            // Tap to cycle
            filterButton.tap()
        }
        
        // Assert we found all expected states
        XCTAssertTrue(foundStates.isSuperset(of: expectedIcons.keys), "Failed to find all expected filter states. Found: \(foundStates)")
    }
}
