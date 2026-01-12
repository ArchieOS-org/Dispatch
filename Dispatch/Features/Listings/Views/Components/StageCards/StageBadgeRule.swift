//
//  StageBadgeRule.swift
//  Dispatch
//
//  Pure function for count visibility - testable without views.
//

import Foundation

/// Pure function for count visibility logic.
/// Extracted for testability and single source of truth.
enum StageBadgeRule {
  /// Determines whether the count should be hidden for a given stage.
  ///
  /// Visibility rules:
  /// - Done stage: always hidden (archival, no actionable count)
  /// - All other stages: always shown, including "0"
  ///
  /// Zero styling: "0" uses the same typography as other counts (no de-emphasis).
  /// VoiceOver: "0 listings" (not "No listings").
  ///
  /// - Parameter stage: The listing stage
  /// - Returns: true if the count should be hidden
  static func shouldHideCount(stage: ListingStage) -> Bool {
    stage == .done
  }
}
