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

    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?

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
        allResults.filtered(by: debouncedQuery)
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
        Group {
            if debouncedQuery.isEmpty {
                emptyPromptView
            } else if isEmpty {
                noResultsView
            } else {
                resultsList
            }
        }
        .onChange(of: searchText) { _, newValue in
            debounceSearch(newValue)
        }
    }

    // MARK: - Subviews

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
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
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(DS.Colors.Text.tertiary)

            Text("Search across all your data")
                .font(.body)
                .foregroundColor(DS.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xxl)
    }

    private var noResultsView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(DS.Colors.Text.tertiary)

            Text("No results for \"\(debouncedQuery)\"")
                .font(.body)
                .foregroundColor(DS.Colors.Text.secondary)

            Text("Try searching for a different term")
                .font(.subheadline)
                .foregroundColor(DS.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xxl)
    }

    // MARK: - Debounce

    private func debounceSearch(_ query: String) {
        debounceTask?.cancel()

        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

            guard !Task.isCancelled else { return }
            debouncedQuery = query
        }
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
