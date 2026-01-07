//
//  QuickEntryItemType.swift
//  Dispatch
//
//  Enum for QuickEntrySheet item type selection
//

import Foundation

/// The type of work item to create via QuickEntrySheet.
/// This determines which fields are shown and what model is created.
enum QuickEntryItemType: String, CaseIterable, Identifiable {
  case task
  case activity

  // MARK: Internal

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .task: "Task"
    case .activity: "Activity"
    }
  }

  var icon: String {
    switch self {
    case .task: DS.Icons.Entity.task
    case .activity: DS.Icons.Entity.activity
    }
  }
}
