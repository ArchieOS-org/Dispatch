//
//  DueDateBadge.swift
//  Dispatch
//
//  Shared Component - Things 3-style due date display
//  Created by Claude on 2025-12-06.
//  Updated for DIS-41: Things 3 style due dates
//

import SwiftUI

/// Displays a due date with Things 3-style formatting:
/// - Flag icon instead of clock
/// - Natural language: "In 3 days", "2 days overdue"
/// - Two-state coloring: Red (overdue), Gray (normal)
/// - Time only shown for today's items with future times
struct DueDateBadge: View {
  let dueDate: Date?

  // MARK: - Color Logic (2-state: red or gray)

  private var dateColor: Color {
    guard let dueDate else { return DS.Colors.Text.tertiary }

    let cal = Self.calendar
    let startOfToday = cal.startOfDay(for: Date())
    let startOfDue = cal.startOfDay(for: dueDate)
    let dayDiff = cal.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0

    // Overdue: past days OR today with past time
    if dayDiff < 0 || (dayDiff == 0 && dueDate < Date()) {
      return DS.Colors.overdue
    }
    return DS.Colors.dueNormal
  }

  // MARK: - Formatted Text (Things 3 Style)

  private var formattedDate: String {
    guard let dueDate else { return "" }

    let cal = Self.calendar
    let now = Date()
    let startOfToday = cal.startOfDay(for: now)
    let startOfDue = cal.startOfDay(for: dueDate)
    let dayDiff = cal.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0

    switch dayDiff {
    case 0:  // Today
      return dueDate > now ? "Today, \(Self.timeFormatter.string(from: dueDate))" : "Today"
    case 1:  // Tomorrow
      return "Tomorrow"
    case 2...7:  // In X days
      return "In \(dayDiff) days"
    case let d where d > 7:  // Future date
      return Self.shortDateFormatter.string(from: dueDate)
    case -1:  // 1 day overdue
      return "1 day overdue"
    default:  // Multiple days overdue
      return "\(abs(dayDiff)) days overdue"
    }
  }

  // MARK: - Date Formatters

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
  }()

  private static let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter
  }()

  private static let calendar = Calendar.current

  // MARK: - Body

  var body: some View {
    if dueDate != nil {
      HStack(spacing: DS.Spacing.xxs) {
        Image(systemName: DS.Icons.Time.deadline)
          .font(.system(size: 10))
        Text(formattedDate)
          .font(DS.Typography.caption)
      }
      .foregroundColor(dateColor)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Due \(formattedDate)")
    }
  }
}

// MARK: - Preview

#Preview("Due Date States - Things 3 Style") {
  VStack(alignment: .leading, spacing: DS.Spacing.md) {
    Group {
      Text("Overdue States").font(.headline)
      DueDateBadge(dueDate: Date().addingTimeInterval(-86400 * 5))  // 5 days overdue
      DueDateBadge(dueDate: Date().addingTimeInterval(-86400 * 2))  // 2 days overdue
      DueDateBadge(dueDate: Date().addingTimeInterval(-86400))  // 1 day overdue
    }

    Divider()

    Group {
      Text("Today States").font(.headline)
      DueDateBadge(dueDate: Date().addingTimeInterval(-3600))  // 1 hour ago (overdue)
      DueDateBadge(dueDate: Date().addingTimeInterval(3600))  // 1 hour from now
      DueDateBadge(dueDate: Date().addingTimeInterval(18000))  // 5 hours from now
    }

    Divider()

    Group {
      Text("Future States").font(.headline)
      DueDateBadge(dueDate: Date().addingTimeInterval(86400))  // Tomorrow
      DueDateBadge(dueDate: Date().addingTimeInterval(86400 * 3))  // In 3 days
      DueDateBadge(dueDate: Date().addingTimeInterval(86400 * 7))  // In 7 days
      DueDateBadge(dueDate: Date().addingTimeInterval(86400 * 14))  // Jan 8 (date format)
    }

    Divider()

    Group {
      Text("Edge Cases").font(.headline)
      DueDateBadge(dueDate: nil)  // No date
    }
  }
  .padding()
}
