//
//  SearchResult.swift
//  Dispatch
//
//  Unified search result type wrapping TaskItem, Activity, or Listing
//  Created by Claude on 2025-12-18.
//

import SwiftUI

// MARK: - SearchResult

/// A unified wrapper for search results across Tasks, Activities, and Listings.
///
/// Provides a common interface for:
/// - Display properties (title, subtitle, icon, color)
/// - Navigation (converting to appropriate navigation values)
/// - Ranking (prefix matching, title vs subtitle)
///
/// **Result Sections:**
/// - Tasks: Title = task title, Subtitle = description or "No description"
/// - Activities: Title = activity title, Subtitle = type label
/// - Listings: Title = address, Subtitle = city + status
enum SearchResult: Identifiable, Hashable {
  case task(TaskItem)
  case activity(Activity)
  case listing(Listing)
  case navigation(title: String, icon: String, tab: AppTab, badgeCount: Int? = nil)
  /// Bridge case for SearchDoc-based results from instant search
  case searchDoc(SearchDoc)

  // MARK: Internal

  var id: UUID {
    switch self {
    case .task(let task): return task.id

    case .activity(let activity): return activity.id

    case .listing(let listing): return listing.id

    case .navigation(let title, _, _, _):
      // Stable UUID based on title for navigation items
      // We implementation a simple stable hash to hex string conversion to ensure persistence stability
      let stableHash = title.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
      let hexSuffix = String(format: "%012x", stableHash & 0xFFFFFFFFFFFF)
      return UUID(uuidString: "DEADBEEF-0000-0000-0000-\(hexSuffix)") ?? UUID()

    case .searchDoc(let doc): return doc.id
    }
  }

  /// Primary display text
  var title: String {
    switch self {
    case .task(let task): task.title
    case .activity(let activity): activity.title
    case .listing(let listing): listing.address.titleCased()
    case .navigation(let title, _, _, _): title
    case .searchDoc(let doc): doc.primaryText
    }
  }

  /// Secondary display text
  var subtitle: String {
    switch self {
    case .task(let task):
      return task.taskDescription.isEmpty ? "No description" : task.taskDescription

    case .activity(let activity):
      // Show due date if available, otherwise assignee count or available
      if let dueDate = activity.dueDate {
        return dueDateSubtitle(for: dueDate)
      } else if !activity.assigneeUserIds.isEmpty {
        let count = activity.assigneeUserIds.count
        return count == 1 ? "1 assignee" : "\(count) assignees"
      } else {
        return "Available"
      }

    case .listing(let listing):
      let status = listing.status.rawValue.capitalized
      return listing.city.isEmpty ? status : "\(listing.city.titleCased()) · \(status)"

    case .navigation: return "Quick Jump"

    case .searchDoc(let doc): return doc.secondaryText
    }
  }

  /// Icon name (SF Symbol)
  var icon: String {
    switch self {
    case .task: DS.Icons.Entity.task
    case .activity: DS.Icons.Entity.activity
    case .listing: DS.Icons.Entity.listing
    case .navigation(_, let icon, _, _): icon
    case .searchDoc(let doc): doc.type.icon
    }
  }

  /// Accent color for the result type
  var accentColor: Color {
    switch self {
    case .task: DS.Colors.Section.tasks
    case .activity: DS.Colors.Section.activities
    case .listing: DS.Colors.Section.listings
    case .navigation: .blue // Standard navigation color
    case .searchDoc(let doc): doc.type.accentColor
    }
  }

  /// Section header title
  var sectionTitle: String {
    switch self {
    case .task: "Tasks"
    case .activity: "Activities"
    case .listing: "Listings"
    case .navigation: "Navigation"
    case .searchDoc(let doc): doc.type.sectionTitle
    }
  }

  /// Whether the item is completed (tasks/activities only)
  var isCompleted: Bool {
    switch self {
    case .task(let task): task.status == .completed
    case .activity(let activity): activity.status == .completed
    case .listing: false
    case .navigation: false
    case .searchDoc: false // SearchDoc doesn't track completion status
    }
  }

  /// Whether the item is deleted
  var isDeleted: Bool {
    switch self {
    case .task(let task): task.status == .deleted
    case .activity(let activity): activity.status == .deleted
    case .listing(let listing): listing.status == .deleted
    case .navigation: false
    case .searchDoc: false // SearchDoc doesn't include deleted items
    }
  }

  /// Sort priority for section ordering (Navigation, then Listings, then Tasks, then Activities)
  var sectionOrder: Int {
    switch self {
    case .navigation: -1 // Navigation always first
    case .listing: 0
    case .task: 1
    case .activity: 2
    case .searchDoc(let doc):
      // Map SearchDocType to section order
      switch doc.type {
      case .realtor: -1 // Realtors first
      case .listing: 0
      case .property: 1
      case .task: 2
      }
    }
  }

  var badgeCount: Int? {
    switch self {
    case .navigation(_, _, _, let count): count
    case .task, .activity, .listing, .searchDoc: nil
    }
  }

  /// The underlying SearchDoc for searchDoc results, nil otherwise
  var searchDocValue: SearchDoc? {
    switch self {
    case .searchDoc(let doc): doc
    default: nil
    }
  }

  // MARK: Private

  /// Formats due date as relative subtitle text
  private func dueDateSubtitle(for date: Date) -> String {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let dueDay = calendar.startOfDay(for: date)

    let daysDiff = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

    if daysDiff < 0 {
      return "Overdue by \(abs(daysDiff)) day\(abs(daysDiff) == 1 ? "" : "s")"
    } else if daysDiff == 0 {
      return "Due today"
    } else if daysDiff == 1 {
      return "Due tomorrow"
    } else if daysDiff <= 7 {
      return "Due in \(daysDiff) days"
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMM d"
      return "Due \(formatter.string(from: date))"
    }
  }

}

// MARK: - Previews

#if DEBUG

private struct SearchResultPreviewRow: View {
  let result: SearchResult

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: result.icon)
        .foregroundStyle(result.accentColor)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(result.title)
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(1)

        Text(result.subtitle)
          .font(DS.Typography.bodySecondary)
          .foregroundStyle(DS.Colors.Text.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      if let badge = result.badgeCount {
        Text("\(badge)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(DS.Colors.Text.primary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.15))
          .clipShape(Capsule())
      }
    }
    .padding(.vertical, 6)
  }
}

#Preview("SearchResult · Navigation Items") {
  List {
    let navigationItems: [SearchResult] = [
      .navigation(title: "My Workspace", icon: "briefcase", tab: .workspace),
      .navigation(title: "Listings", icon: DS.Icons.Entity.listing, tab: .listings),
      .navigation(title: "Properties", icon: DS.Icons.Entity.property, tab: .properties),
      .navigation(title: "Realtors", icon: DS.Icons.Entity.realtor, tab: .realtors)
    ]
    ForEach(navigationItems) { result in
      SearchResultPreviewRow(result: result)
    }
  }
  .navigationTitle("SearchResult")
}

#endif
