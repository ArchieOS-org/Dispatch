//
//  GeneratorStatus.swift
//  Dispatch
//
//  Status states for AI-generated listing descriptions.
//  Tracks the workflow from generation to posting.
//

import SwiftUI

// MARK: - GeneratorStatus

/// Represents the lifecycle state of a generated listing description.
/// Named GeneratorStatus to avoid conflict with ListingStatus (listing entity status).
enum GeneratorStatus: String, CaseIterable, Identifiable {
  /// Just generated, not yet sent for review
  case draft
  /// Sent to agent for approval
  case sent
  /// Agent has approved the description
  case ready
  /// Description has been posted to MLS
  case posted

  // MARK: Internal

  var id: String { rawValue }

  /// Display title for the status
  var title: String {
    switch self {
    case .draft: "Draft"
    case .sent: "Sent"
    case .ready: "Ready"
    case .posted: "Posted"
    }
  }

  /// SF Symbol icon for the status
  var icon: String {
    switch self {
    case .draft: "doc.text"
    case .sent: "paperplane"
    case .ready: "checkmark.circle"
    case .posted: "checkmark.seal.fill"
    }
  }

  /// Color associated with the status
  var color: Color {
    switch self {
    case .draft: DS.Colors.Text.tertiary
    case .sent: DS.Colors.info
    case .ready: DS.Colors.success
    case .posted: DS.Colors.accent
    }
  }
}
