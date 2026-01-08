//
//  ContentKind.swift
//  Dispatch
//
//  Content type filter for showing Tasks, Activities, or All
//

import Foundation

/// Filter mode for viewing work items by content type.
/// Used in the long-press menu to filter between tasks, activities, or all.
enum ContentKind: String, CaseIterable {
  case all
  case tasks
  case activities

  // MARK: Internal

  /// Returns the next kind in the cycle: All → Tasks → Activities → All
  var next: ContentKind {
    switch self {
    case .all: .tasks
    case .tasks: .activities
    case .activities: .all
    }
  }

  /// Display label for the filter
  var label: String {
    switch self {
    case .all: "All"
    case .tasks: "Tasks"
    case .activities: "Activities"
    }
  }
}
