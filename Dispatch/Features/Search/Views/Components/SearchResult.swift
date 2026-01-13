//
//  SearchResult.swift
//  Dispatch
//
//  Unified search result type wrapping TaskItem, Activity, or Listing
//  Created by Claude on 2025-12-18.
//

import SwiftData
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
    }
  }

  /// Primary display text
  var title: String {
    switch self {
    case .task(let task): task.title
    case .activity(let activity): activity.title
    case .listing(let listing): listing.address
    case .navigation(let title, _, _, _): title
    }
  }

  /// Secondary display text
  var subtitle: String {
    switch self {
    case .task(let task):
      return task.taskDescription.isEmpty ? "No description" : task.taskDescription

    case .activity(let activity):
      // Show due date if available, otherwise assignee count or unassigned
      if let dueDate = activity.dueDate {
        return dueDateSubtitle(for: dueDate)
      } else if !activity.assigneeUserIds.isEmpty {
        let count = activity.assigneeUserIds.count
        return count == 1 ? "1 assignee" : "\(count) assignees"
      } else {
        return "Unassigned"
      }

    case .listing(let listing):
      let status = listing.status.rawValue.capitalized
      return listing.city.isEmpty ? status : "\(listing.city) · \(status)"

    case .navigation: return "Quick Jump"
    }
  }

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

  /// Icon name (SF Symbol)
  var icon: String {
    switch self {
    case .task: DS.Icons.Entity.task
    case .activity: DS.Icons.Entity.activity
    case .listing: DS.Icons.Entity.listing
    case .navigation(_, let icon, _, _): icon
    }
  }

  /// Accent color for the result type
  var accentColor: Color {
    switch self {
    case .task: DS.Colors.Section.tasks
    case .activity: DS.Colors.Section.activities
    case .listing: DS.Colors.Section.listings
    case .navigation: .blue // Standard navigation color
    }
  }

  /// Section header title
  var sectionTitle: String {
    switch self {
    case .task: "Tasks"
    case .activity: "Activities"
    case .listing: "Listings"
    case .navigation: "Navigation"
    }
  }

  /// Whether the item is completed (tasks/activities only)
  var isCompleted: Bool {
    switch self {
    case .task(let task): task.status == .completed
    case .activity(let activity): activity.status == .completed
    case .listing: false
    case .navigation: false
    }
  }

  /// Whether the item is deleted
  var isDeleted: Bool {
    switch self {
    case .task(let task): task.status == .deleted
    case .activity(let activity): activity.status == .deleted
    case .listing(let listing): listing.status == .deleted
    case .navigation: false
    }
  }

  /// Sort priority for section ordering (Navigation, then Listings, then Tasks, then Activities)
  var sectionOrder: Int {
    switch self {
    case .navigation: -1 // Navigation always first
    case .listing: 0
    case .task: 1
    case .activity: 2
    }
  }

  var badgeCount: Int? {
    switch self {
    case .navigation(_, _, _, let count): count
    default: nil
    }
  }
}

// MARK: - Previews

#if DEBUG

private enum SearchResultPreviewData {
  static func makeResults(context: ModelContext) -> [SearchResult] {
    // Seed base data if available in your preview harness
    PreviewDataFactory.seed(context)

    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []
    let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
    let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []

    // Mix a few of each type for sectioning + ranking
    let listingResults = listings.prefix(6).map { SearchResult.listing($0) }
    let taskResults = tasks.prefix(10).map { SearchResult.task($0) }
    let activityResults = activities.prefix(10).map { SearchResult.activity($0) }

    return taskResults + activityResults + listingResults
  }
}

private struct SearchResultPreviewRow: View {
  let result: SearchResult

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: result.icon)
        .foregroundStyle(result.accentColor)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(result.title)
          .font(.headline)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(1)

        Text(result.subtitle)
          .font(.subheadline)
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

private struct SearchResultsPreviewList: View {
  let results: [SearchResult]
  @State var query: String

  var body: some View {
    List {
      if query.isEmpty {
        Section {
          Text("Type to filter results")
            .foregroundStyle(DS.Colors.Text.secondary)
        }
      } else if results.filtered(by: query).isEmpty {
        Section {
          Text("No matches")
            .foregroundStyle(DS.Colors.Text.secondary)
        }
      } else {
        ForEach(results.filtered(by: query).prefix(60)) { result in
          SearchResultPreviewRow(result: result)
        }
      }
    }
    .navigationTitle("SearchResult")
    #if os(iOS)
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
    #else
      .searchable(text: $query, prompt: "Search")
    #endif
  }
}

#Preview("SearchResult · Grouped + Filtered") {
  PreviewShell { context in
    let results = SearchResultPreviewData.makeResults(context: context)

    NavigationStack {
      SearchResultsPreviewList(results: results, query: "a")
    }
  }
}

#Preview("SearchResult · Ranking (prefix vs contains)") {
  PreviewShell(setup: { context in
    PreviewDataFactory.seed(context)

    // Add a few deterministic titles so ranking differences are obvious
    let listing = (try? context.fetch(FetchDescriptor<Listing>()).first)

    let t1 = TaskItem(
      title: "Fix Broken Window",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      listingId: listing?.id,
      assigneeUserIds: [PreviewDataFactory.bobID]
    )
    let t2 = TaskItem(
      title: "Window Measurements",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      listingId: listing?.id,
      assigneeUserIds: [PreviewDataFactory.bobID]
    )
    let t3 = TaskItem(
      title: "Schedule contractor",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      listingId: listing?.id,
      assigneeUserIds: [PreviewDataFactory.bobID]
    )

    context.insert(t1)
    context.insert(t2)
    context.insert(t3)
    try? context.save()
  }) { context in
    let results = SearchResultPreviewData.makeResults(context: context)

    NavigationStack {
      SearchResultsPreviewList(results: results, query: "win")
    }
  }
}

#endif

// MARK: - Filtering & Ranking

extension SearchResult {
  /// Checks if this result matches the given query (case-insensitive)
  func matches(query: String) -> Bool {
    let lowercasedQuery = query.lowercased()
    return title.lowercased().contains(lowercasedQuery) ||
      subtitle.lowercased().contains(lowercasedQuery)
  }

  /// Calculates a ranking score for sorting results.
  /// Higher score = better match.
  ///
  /// Ranking priorities:
  /// 1. Prefix match on title (highest)
  /// 2. Contains match on title
  /// 3. Prefix match on subtitle
  /// 4. Contains match on subtitle (lowest)
  /// 5. Open items beat completed items
  func rankingScore(for query: String) -> Int {
    let lowercasedQuery = query.lowercased()
    let lowercasedTitle = title.lowercased()
    let lowercasedSubtitle = subtitle.lowercased()

    var score = 0

    // Prefix match on title is highest priority
    if lowercasedTitle.hasPrefix(lowercasedQuery) {
      score += 1000
    } else if lowercasedTitle.contains(lowercasedQuery) {
      score += 500
    }

    // Subtitle matches are lower priority
    if lowercasedSubtitle.hasPrefix(lowercasedQuery) {
      score += 100
    } else if lowercasedSubtitle.contains(lowercasedQuery) {
      score += 50
    }

    // Open items rank higher than completed
    if !isCompleted {
      score += 10
    }

    return score
  }
}

// MARK: - Search Result Collection Helpers

extension [SearchResult] {
  /// Filters results matching the query and sorts by ranking score
  func filtered(by query: String) -> [SearchResult] {
    guard !query.isEmpty else { return [] }

    return filter { !$0.isDeleted && $0.matches(query: query) }
      .sorted {
        let lhsScore = $0.rankingScore(for: query)
        let rhsScore = $1.rankingScore(for: query)
        if lhsScore != rhsScore { return lhsScore > rhsScore }

        // Tie-break 1: type priority
        if $0.sectionOrder != $1.sectionOrder { return $0.sectionOrder < $1.sectionOrder }

        // Tie-break 2: open before completed
        if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }

        // Tie-break 3: stable alpha
        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
  }

  /// Groups results by section with per-section limit
  func groupedBySectionWithLimit(_ limit: Int = 20) -> [(section: String, results: [SearchResult])] {
    let grouped = Dictionary(grouping: self) { $0.sectionTitle }

    return grouped
      .map { (section: $0.key, results: Array($0.value.prefix(limit))) }
      .sorted { lhs, rhs in
        // Sort sections: Navigation, Listings, Tasks, Activities
        let lhsOrder = lhs.results.first?.sectionOrder ?? 0
        let rhsOrder = rhs.results.first?.sectionOrder ?? 0
        return lhsOrder < rhsOrder
      }
  }
}
