//
//  SearchResultsList.swift
//  Dispatch
//
//  Sectioned list of search results with filtering and debouncing
//  Created by Claude on 2025-12-18.
//

import Combine
import SwiftData
import SwiftUI

/// A list view displaying search results grouped by section.
///
/// Features:
/// - Debounced search input (150ms) for performance
/// - Results grouped by type (Tasks, Activities, Listings)
/// - Ranked by relevance (prefix match > contains, title > subtitle)
/// - Per-section result cap (20 items)
/// - Empty state handling
struct SearchResultsList: View {

  // MARK: Internal

  let searchText: String
  let tasks: [TaskItem]
  let activities: [Activity]
  let listings: [Listing]
  var onSelectResult: (SearchResult) -> Void

  // Debounce removed - using live search text directly

  var body: some View {
    VStack(spacing: 0) {
      if searchText.isEmpty {
        emptyPromptView
      } else if filteredResults.isEmpty { // Use filteredResults directly, skip debounce for now
        noResultsView
      } else {
        resultsList
      }
    }
    // Removed debounce logic to rule out Task creation loops
  }

  // MARK: Private

  /// All items converted to SearchResult
  private var allResults: [SearchResult] {
    var results = [SearchResult]()
    results.append(contentsOf: tasks.map { .task($0) })
    results.append(contentsOf: activities.map { .activity($0) })
    results.append(contentsOf: listings.map { .listing($0) })
    return results
  }

  /// Filtered and ranked results
  private var filteredResults: [SearchResult] {
    allResults.filtered(by: searchText)
  }

  /// Results grouped by section
  private var groupedResults: [(section: String, results: [SearchResult])] {
    filteredResults.groupedBySectionWithLimit(20)
  }

  /// Whether results are empty
  private var isEmpty: Bool {
    groupedResults.isEmpty
  }

  private var resultsList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(groupedResults, id: \.section) { section, results in
          sectionHeader(section)

          ForEach(results) { result in
            Button {
              onSelectResult(result)
            } label: {
              SearchResultRow(result: result)
            }
            .buttonStyle(.plain)

            if result.id != results.last?.id {
              Divider()
                .padding(.leading, DS.Spacing.lg + DS.Spacing.avatarMedium + DS.Spacing.md)
            }
          }
        }
      }
    }
  }

  private var emptyPromptView: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        // Quick Jump Header
        sectionHeader("Quick Jump")

        // Navigation Items
        let navigationItems: [SearchResult] = [
          .navigation(title: "My Workspace", icon: "briefcase", tab: .workspace),
          .navigation(title: "Realtors", icon: DS.Icons.Entity.realtor, tab: .realtors),
          .navigation(title: "Listings", icon: DS.Icons.Entity.listing, tab: .listings)
        ]

        ForEach(navigationItems) { result in
          Button {
            onSelectResult(result)
          } label: {
            SearchResultRow(result: result)
          }
          .buttonStyle(.plain)

          if result.id != navigationItems.last?.id {
            Divider()
              .padding(.leading, DS.Spacing.lg + DS.Spacing.avatarMedium + DS.Spacing.md)
          }
        }
      }
    }
  }

  private var noResultsView: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.largeTitle)
        .foregroundColor(DS.Colors.Text.tertiary)

      Text("No results for \"\(searchText)\"")
        .font(.body)
        .foregroundColor(DS.Colors.Text.secondary)

      Text("Try searching for a different term")
        .font(.subheadline)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(DS.Spacing.xxl)
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.subheadline)
      .fontWeight(.semibold)
      .foregroundColor(DS.Colors.Text.secondary)
      .padding(.horizontal, DS.Spacing.lg)
      .padding(.top, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.sm)
  }

}

// MARK: - Preview

#if DEBUG

private enum SearchResultsListPreviewData {
  static func seedAndCustomize(_ context: ModelContext) {
    PreviewDataFactory.seed(context)

    // Make at least one listing match common queries so the Listings section appears.
    if let listing = try? context.fetch(FetchDescriptor<Listing>()).first {
      listing.address = "123 Window St"
      try? context.save()
    }

    // Add deterministic items so ranking/sectioning is obvious.
    let listing = (try? context.fetch(FetchDescriptor<Listing>()).first)

    let t1 = TaskItem(
      title: "Fix Broken Window",
      taskDescription: "Replace pane + schedule contractor",
      dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
      priority: .high,
      declaredBy: PreviewDataFactory.aliceID,
      claimedBy: PreviewDataFactory.bobID,
      listingId: listing?.id
    )
    t1.syncState = .synced

    let t2 = TaskItem(
      title: "Window Measurements",
      taskDescription: "Confirm dimensions",
      dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
      priority: .medium,
      declaredBy: PreviewDataFactory.aliceID,
      claimedBy: PreviewDataFactory.bobID,
      listingId: listing?.id
    )
    t2.syncState = .synced

    let a1 = Activity(
      title: "Window inspection call",
      activityDescription: "Confirm scope + pricing",
      type: .call,
      priority: .medium,
      declaredBy: PreviewDataFactory.aliceID,
      claimedBy: PreviewDataFactory.bobID,
      listingId: listing?.id
    )
    a1.syncState = .synced

    context.insert(t1)
    context.insert(t2)
    context.insert(a1)

    // Add extra items so scrolling + dividers are exercised.
    for idx in 1...16 {
      let task = TaskItem(
        title: "Follow up vendor #\(idx)",
        taskDescription: idx % 2 == 0 ? "Email + timeline" : "Call + confirm details",
        dueDate: Calendar.current.date(byAdding: .day, value: idx, to: Date()),
        priority: idx % 3 == 0 ? .high : .low,
        declaredBy: PreviewDataFactory.aliceID,
        claimedBy: PreviewDataFactory.bobID,
        listingId: listing?.id
      )
      task.syncState = .synced
      context.insert(task)
    }

    try? context.save()
  }

  static func fetch(_ context: ModelContext) -> (tasks: [TaskItem], activities: [Activity], listings: [Listing]) {
    let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
    let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []
    return (tasks, activities, listings)
  }
}

private struct SearchResultsListPreviewHost: View {
  let tasks: [TaskItem]
  let activities: [Activity]
  let listings: [Listing]
  let initialQuery: String

  @State private var query: String

  init(tasks: [TaskItem], activities: [Activity], listings: [Listing], initialQuery: String) {
    self.tasks = tasks
    self.activities = activities
    self.listings = listings
    self.initialQuery = initialQuery
    _query = State(initialValue: initialQuery)
  }

  var body: some View {
    SearchResultsList(
      searchText: query,
      tasks: tasks,
      activities: activities,
      listings: listings,
      onSelectResult: { _ in }
    )
    .background(DS.Colors.Background.primary)
    .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
    .navigationTitle("SearchResultsList")
  }
}

#Preview("SearchResultsList · Quick Jump") {
  PreviewShell(setup: { context in
    SearchResultsListPreviewData.seedAndCustomize(context)
  }) { context in
    let data = SearchResultsListPreviewData.fetch(context)

    NavigationStack {
      SearchResultsListPreviewHost(
        tasks: data.tasks,
        activities: data.activities,
        listings: data.listings,
        initialQuery: ""
      )
    }
  }
}

#Preview("SearchResultsList · No Results") {
  PreviewShell(setup: { context in
    SearchResultsListPreviewData.seedAndCustomize(context)
  }) { context in
    let data = SearchResultsListPreviewData.fetch(context)

    NavigationStack {
      SearchResultsListPreviewHost(
        tasks: data.tasks,
        activities: data.activities,
        listings: data.listings,
        initialQuery: "zzzzzz"
      )
    }
  }
}

#Preview("SearchResultsList · Mixed Results") {
  PreviewShell(setup: { context in
    SearchResultsListPreviewData.seedAndCustomize(context)
  }) { context in
    let data = SearchResultsListPreviewData.fetch(context)

    NavigationStack {
      SearchResultsListPreviewHost(
        tasks: data.tasks,
        activities: data.activities,
        listings: data.listings,
        initialQuery: "win"
      )
    }
  }
}

#Preview("SearchResultsList · Long List") {
  PreviewShell(setup: { context in
    SearchResultsListPreviewData.seedAndCustomize(context)
  }) { context in
    let data = SearchResultsListPreviewData.fetch(context)

    NavigationStack {
      SearchResultsListPreviewHost(
        tasks: data.tasks,
        activities: data.activities,
        listings: data.listings,
        initialQuery: "follow"
      )
    }
  }
}

#endif
