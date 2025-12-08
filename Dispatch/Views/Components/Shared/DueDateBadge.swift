//
//  DueDateBadge.swift
//  Dispatch
//
//  Shared Component - Contextual due date display with overdue styling
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// Displays a due date with contextual coloring based on urgency.
/// - Overdue: Red
/// - Due soon (< 24h): Orange
/// - Normal: Secondary text color
struct DueDateBadge: View {
    let dueDate: Date?

    private var dateColor: Color {
        guard let dueDate else { return DS.Colors.Text.tertiary }

        let now = Date()
        if dueDate < now {
            return DS.Colors.overdue
        } else if dueDate.timeIntervalSince(now) < 24 * 60 * 60 {
            return DS.Colors.dueSoon
        } else {
            return DS.Colors.dueNormal
        }
    }

    private var formattedDate: String {
        guard let dueDate else { return "" }

        let now = Date()

        if Self.calendar.isDateInToday(dueDate) {
            return "Today, \(Self.timeFormatter.string(from: dueDate))"
        } else if Self.calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow, \(Self.timeFormatter.string(from: dueDate))"
        } else if Self.calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else if dueDate < now {
            return "Overdue: \(Self.shortDateFormatter.string(from: dueDate))"
        } else {
            return Self.shortDateFormatter.string(from: dueDate)
        }
    }

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

    var body: some View {
        if let _ = dueDate {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: DS.Icons.Time.clock)
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

#Preview("Due Date States") {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
        DueDateBadge(dueDate: Date().addingTimeInterval(-86400)) // Yesterday
        DueDateBadge(dueDate: Date().addingTimeInterval(3600)) // 1 hour
        DueDateBadge(dueDate: Date().addingTimeInterval(86400)) // Tomorrow
        DueDateBadge(dueDate: Date().addingTimeInterval(86400 * 7)) // Next week
        DueDateBadge(dueDate: nil) // No date
    }
    .padding()
}
