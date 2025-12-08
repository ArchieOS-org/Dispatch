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

    var id: String { rawValue }

    private static let calendar = Calendar.current

    /// Returns the appropriate header color for this section
    var headerColor: Color {
        self == .overdue ? DS.Colors.overdue : DS.Colors.Text.primary
    }

    /// Determines which section a given date belongs to
    /// - Parameter date: The due date to categorize (nil returns .noDueDate)
    /// - Returns: The appropriate DateSection for the date
    static func section(for date: Date?) -> DateSection {
        guard let date else { return .noDueDate }

        let startOfToday = calendar.startOfDay(for: Date())

        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
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
    /// - Parameter items: Array of WorkItem to group
    /// - Returns: Dictionary mapping DateSection to arrays of WorkItem
    static func group(_ items: [WorkItem]) -> [DateSection: [WorkItem]] {
        Dictionary(grouping: items) { section(for: $0.dueDate) }
    }

    /// Returns sorted sections with their items, excluding empty sections
    /// - Parameter items: Array of WorkItem to group and sort
    /// - Returns: Array of tuples containing section and its items, in section order
    static func sortedSections(from items: [WorkItem]) -> [(section: DateSection, items: [WorkItem])] {
        let grouped = group(items)
        return DateSection.allCases.compactMap { section in
            guard let sectionItems = grouped[section], !sectionItems.isEmpty else { return nil }
            // Sort items within section by due date
            let sorted = sectionItems.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            return (section, sorted)
        }
    }
}
