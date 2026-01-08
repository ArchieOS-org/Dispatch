//
//  DateSection.swift
//  Dispatch
//
//  Utility for grouping work items by date sections
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// Represents date-based sections for grouping work items in list views.
/// Items are categorized as Overdue, Today, Tomorrow, Upcoming, or No Due Date.
enum DateSection: String, CaseIterable, Identifiable {
  case overdue = "Overdue"
  case today = "Today"
  case tomorrow = "Tomorrow"
  case upcoming = "Upcoming"
  case noDueDate = "No Due Date"

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// Returns the appropriate header color for this section
  var headerColor: Color {
    self == .overdue ? DS.Colors.overdue : DS.Colors.Text.primary
  }

  /// Determines which section a given date belongs to
  /// - Parameters:
  ///   - date: The due date to categorize (nil returns .noDueDate)
  ///   - referenceDate: The reference date for "today" (defaults to current date)
  /// - Returns: The appropriate DateSection for the date
  static func section(for date: Date?, referenceDate: Date = Date()) -> DateSection {
    guard let date else { return .noDueDate }

    let startOfToday = calendar.startOfDay(for: referenceDate)

    guard
      let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
      let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday)
    else {
      return .upcoming
    }

    if date < startOfToday {
      return .overdue
    } else if date < startOfTomorrow {
      return .today
    } else if date < startOfDayAfter {
      return .tomorrow
    } else {
      return .upcoming
    }
  }

  /// Groups work items by date section
  /// - Parameters:
  ///   - items: Array of WorkItem to group
  ///   - referenceDate: The reference date for "today" (defaults to current date)
  /// - Returns: Dictionary mapping DateSection to arrays of WorkItem
  static func group(_ items: [WorkItem], referenceDate: Date = Date()) -> [DateSection: [WorkItem]] {
    Dictionary(grouping: items) { section(for: $0.dueDate, referenceDate: referenceDate) }
  }

  /// Returns sorted sections with their items, excluding empty sections
  /// - Parameters:
  ///   - items: Array of WorkItem to group and sort
  ///   - referenceDate: The reference date for "today" (defaults to current date)
  /// - Returns: Array of tuples containing section and its items, in section order
  static func sortedSections(from items: [WorkItem], referenceDate: Date = Date()) -> [(
    section: DateSection,
    items: [WorkItem]
  )] {
    let grouped = group(items, referenceDate: referenceDate)
    return DateSection.allCases.compactMap { section in
      guard let sectionItems = grouped[section], !sectionItems.isEmpty else { return nil }
      // Sort items within section by due date
      let sorted = sectionItems.sorted {
        ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
      }
      return (section, sorted)
    }
  }

  // MARK: Private

  private static let calendar = Calendar.current

}
