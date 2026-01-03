//
//  StageBadgeRule.swift
//  Dispatch
//
//  Pure function for badge visibility - testable without views.
//

import Foundation

/// Pure function for badge visibility logic.
/// Extracted for testability and single source of truth.
enum StageBadgeRule {
    /// Determines whether the badge should be hidden for a given stage and count.
    /// - Parameters:
    ///   - stage: The listing stage
    ///   - count: The number of listings in this stage
    /// - Returns: true if the badge should be hidden
    static func shouldHide(stage: ListingStage, count: Int) -> Bool {
        stage == .done || count == 0
    }
}
