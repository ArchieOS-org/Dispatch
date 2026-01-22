//
//  InstantSearchResultsList.swift
//  Dispatch
//
//  Search results list powered by SearchViewModel and instant indexing.
//  Uses SearchDoc-based results with proper ranking and grouping.
//

import SwiftUI

// MARK: - InstantSearchResultsList

/// A list view displaying instant search results from SearchViewModel.
///
/// Features:
/// - Uses debounced SearchViewModel for background-indexed search
/// - Results grouped by type (Realtors, Listings, Properties, Tasks)
/// - NO Activities (excluded per contract)
/// - Ranked by phrase match > token coverage > type priority > recency
struct InstantSearchResultsList: View {

  // MARK: Internal

  /// The SearchViewModel providing search state and results
  @ObservedObject var searchViewModel: SearchViewModel

  /// Callback when a result is selected
  var onSelectResult: (SearchResult) -> Void

  var body: some View {
    VStack(spacing: 0) {
      if searchViewModel.query.isEmpty {
        emptyPromptView
      } else if searchViewModel.searchDocResults.isEmpty, !searchViewModel.isSearching {
        noResultsView
      } else {
        resultsList
      }
    }
  }

  // MARK: Private

  private var resultsList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(searchViewModel.groupedResults(), id: \.section) { section, results in
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

        // Show loading indicator while searching
        if searchViewModel.isSearching {
          HStack {
            Spacer()
            ProgressView()
              .padding(DS.Spacing.md)
            Spacer()
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
          .navigation(title: "Listings", icon: DS.Icons.Entity.listing, tab: .listings),
          .navigation(title: "Properties", icon: DS.Icons.Entity.property, tab: .properties),
          .navigation(title: "Realtors", icon: DS.Icons.Entity.realtor, tab: .realtors)
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
        .font(DS.Typography.largeTitle)
        .foregroundColor(DS.Colors.Text.tertiary)

      Text("No results for \"\(searchViewModel.query)\"")
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.secondary)

      Text("Try searching for a different term")
        .font(DS.Typography.bodySecondary)
        .foregroundColor(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(DS.Spacing.xxl)
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(DS.Typography.bodySecondary)
      .fontWeight(.semibold)
      .foregroundColor(DS.Colors.Text.secondary)
      .padding(.horizontal, DS.Spacing.lg)
      .padding(.top, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.sm)
  }

}

// MARK: - Preview

#if DEBUG

private struct InstantSearchResultsListPreviewHost: View {

  // MARK: Internal

  @StateObject var searchViewModel = SearchViewModel()

  var body: some View {
    VStack(spacing: 0) {
      TextField("Search", text: $query)
        .textFieldStyle(.roundedBorder)
        .padding()
        .onChange(of: query) { _, newValue in
          searchViewModel.onQueryChange(newValue)
        }

      Divider()

      InstantSearchResultsList(
        searchViewModel: searchViewModel,
        onSelectResult: { _ in }
      )
    }
    .task {
      // Simulate warm start with mock data
      let mockData = InitialSearchData(
        realtors: [],
        listings: [],
        properties: [],
        tasks: []
      )
      await searchViewModel.warmStart(with: mockData)
    }
  }

  // MARK: Private

  @State private var query = ""

}

#Preview("InstantSearchResultsList") {
  InstantSearchResultsListPreviewHost()
    .frame(height: 500)
}

#endif
