//
//  SearchResultRow.swift
//  Dispatch
//
//  Individual search result row with icon, title, subtitle, and chevron
//  Created by Claude on 2025-12-18.
//

import SwiftUI

/// A row component for displaying a single search result.
///
/// Layout:
/// - Colored icon circle (left)
/// - Title and subtitle stack (center, expanding)
/// - Chevron indicator (right)
struct SearchResultRow: View {

  // MARK: Internal

  let result: SearchResult

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Icon circle
      iconView

      // Text content
      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(result.title)
          .font(.body)
          .foregroundColor(result.isCompleted ? DS.Colors.Text.secondary : DS.Colors.Text.primary)
          .lineLimit(1)
          .strikethrough(result.isCompleted)

        Text(result.subtitle)
          .font(.subheadline)
          .foregroundColor(DS.Colors.Text.tertiary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      // Badge (if exists)
      if let badge = result.badgeCount, badge > 0 {
        Text("\(badge)")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(DS.Colors.Text.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(DS.Colors.Background.tertiary)
          .cornerRadius(4)
      }

      // Chevron
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(DS.Colors.Text.quaternary)
    }
    .padding(.horizontal, DS.Spacing.lg)
    .padding(.vertical, DS.Spacing.md)
    .frame(minHeight: DS.Spacing.searchResultRowHeight)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(result.sectionTitle): \(result.title)")
    .accessibilityHint(result.subtitle)
  }

  // MARK: Private

  private var iconView: some View {
    ZStack {
      Circle()
        .fill(result.accentColor.opacity(0.15))
        .frame(width: DS.Spacing.avatarMedium, height: DS.Spacing.avatarMedium)

      Image(systemName: result.icon)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(result.accentColor)
    }
  }
}

// MARK: - Previews

#Preview("Task Result") {
  let task = TaskItem(
    title: "Review quarterly report",
    taskDescription: "Go through Q4 numbers",
    dueDate: Date(),
    priority: .high,
    declaredBy: UUID(),
  )
  SearchResultRow(result: .task(task))
    .background(DS.Colors.Background.primary)
}

#Preview("Activity Result") {
  let activity = Activity(
    title: "Client meeting",
    activityDescription: "Discuss contract terms",
    type: .meeting,
    priority: .medium,
    declaredBy: UUID(),
  )
  SearchResultRow(result: .activity(activity))
    .background(DS.Colors.Background.primary)
}

#Preview("Listing Result") {
  let listing = Listing(
    address: "123 Main Street",
    city: "Toronto",
    province: "ON",
    postalCode: "M5V 1A1",
    country: "Canada",
    ownedBy: UUID(),
  )
  SearchResultRow(result: .listing(listing))
    .background(DS.Colors.Background.primary)
}
