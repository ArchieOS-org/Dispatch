//
//  SearchResultsList.swift
//  Dispatch
//
//  Sectioned list of search results with filtering and debouncing
//  Created by Claude on 2025-12-18.
//

import SwiftUI
import Combine

/// A list view displaying search results grouped by section.
///
/// Features:
/// - Debounced search input (150ms) for performance
/// - Results grouped by type (Tasks, Activities, Listings)
/// - Ranked by relevance (prefix match > contains, title > subtitle)
/// - Per-section result cap (20 items)
/// - Empty state handling
struct SearchResultsList: View {
    let searchText: String
    let tasks: [TaskItem]
    let activities: [Activity]
    let listings: [Listing]
    var onSelectResult: (SearchResult) -> Void

    // Debounce removed - using live search text directly

    // MARK: - Computed Properties

    /// All items converted to SearchResult
    private var allResults: [SearchResult] {
        var results: [SearchResult] = []
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

    // MARK: - Body

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

    // MARK: - Subviews

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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(DS.Colors.Text.secondary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.sm)
    }

    private var emptyPromptView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Quick Jump Header
                sectionHeader("Quick Jump")
                
                // Navigation Items
                let navigationItems: [SearchResult] = [
                    .navigation(title: "Tasks", icon: DS.Icons.Entity.task, tab: .tasks),
                    .navigation(title: "Activities", icon: DS.Icons.Entity.activity, tab: .activities),
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
}

// MARK: - Preview

#Preview("Search Results List") {
    let tasks = [
        TaskItem(title: "Review quarterly report", taskDescription: "Q4 analysis", dueDate: Date(), priority: .high, declaredBy: UUID()),
        TaskItem(title: "Update client database", taskDescription: "Enter new clients", dueDate: nil, priority: .medium, declaredBy: UUID())
    ]

    let activities = [
        Activity(title: "Client call", activityDescription: "Follow up", type: .call, priority: .medium, declaredBy: UUID())
    ]

    let listings: [Listing] = []

    return SearchResultsList(
        searchText: "review",
        tasks: tasks,
        activities: activities,
        listings: listings,
        onSelectResult: { _ in }
    )
    .background(DS.Colors.Background.primary)
}
