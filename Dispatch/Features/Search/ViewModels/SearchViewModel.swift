//
//  SearchViewModel.swift
//  Dispatch
//
//  ViewModel for instant search with debounced queries and background indexing.
//

import Combine
import Foundation
import os

// MARK: - Logger

private let logger = Logger(subsystem: "com.dispatch.app", category: "SearchViewModel")

// MARK: - SearchViewModel

/// ViewModel managing search state and coordinating with SearchIndexService.
///
/// Features:
/// - Debounced search input (200ms) for performance
/// - Cancels previous search task on new query
/// - Bridges SearchDoc results to SearchResult for UI compatibility
/// - Supports warm start for background indexing
///
/// Usage:
/// ```swift
/// @StateObject private var searchViewModel = SearchViewModel()
///
/// .task {
///   await searchViewModel.warmStart(with: initialData)
/// }
/// ```
@MainActor
final class SearchViewModel: ObservableObject {

  // MARK: Lifecycle

  init(searchIndex: SearchIndexService = SearchIndexService()) {
    self.searchIndex = searchIndex
  }

  // MARK: Internal

  /// Current search query text
  @Published var query: String = ""

  /// Search results as SearchDoc for new search system
  @Published var searchDocResults: [SearchDoc] = []

  /// Whether the index is ready for queries
  @Published var isIndexReady: Bool = false

  /// Whether a search is currently in progress
  @Published var isSearching: Bool = false

  /// Cached grouped results for view consumption.
  /// Updated only when searchDocResults changes, avoiding O(n log n) sort per render.
  @Published private(set) var cachedGroupedResults: [(section: String, results: [SearchResult])] = []

  /// The underlying search index service
  let searchIndex: SearchIndexService

  /// Called when query text changes. Debounces and performs search.
  /// - Parameter newQuery: The new query string
  func onQueryChange(_ newQuery: String) {
    query = newQuery

    // Cancel any previous search task
    if searchTask != nil {
      logger.debug("onQueryChange: cancelling previous search task")
      searchTask?.cancel()
    }

    // Clear results immediately if query is empty
    if newQuery.isEmpty {
      logger.debug("onQueryChange: empty query, clearing results")
      searchDocResults = []
      cachedGroupedResults = []
      isSearching = false
      return
    }

    logger.debug("onQueryChange: query='\(newQuery)' starting 200ms debounce")
    isSearching = true

    // Start new debounced search task
    searchTask = Task { [weak self] in
      // Debounce: wait 200ms before searching
      do {
        try await Task.sleep(for: .milliseconds(200))
      } catch {
        logger.debug("onQueryChange: debounce cancelled for query='\(newQuery)'")
        return
      }

      guard !Task.isCancelled else {
        logger.debug("onQueryChange: task cancelled before search for query='\(newQuery)'")
        return
      }

      // Perform search
      guard let self else { return }
      let searchStartTime = CFAbsoluteTimeGetCurrent()
      let results = await searchIndex.search(newQuery, limit: 30)

      guard !Task.isCancelled else {
        logger.debug("onQueryChange: task cancelled after search for query='\(newQuery)'")
        return
      }

      let duration = (CFAbsoluteTimeGetCurrent() - searchStartTime) * 1000
      logger
        .info(
          "onQueryChange: search complete query='\(newQuery)' results=\(results.count) duration=\(duration, format: .fixed(precision: 2))ms"
        )

      // Update results on main actor
      searchDocResults = results
      cachedGroupedResults = groupedResults(from: results)
      isSearching = false
    }
  }

  /// Warms up the search index with initial data. Call after first frame renders.
  /// - Parameter data: Initial data bundle containing entities to index
  func warmStart(with data: InitialSearchData) async {
    logger.info("warmStart: triggering index warm start")
    await searchIndex.warmStart(with: data)
    isIndexReady = await searchIndex.isReady
    // swiftformat:disable:next redundantSelf
    logger.info("warmStart: index ready=\(self.isIndexReady)")
  }

  /// Applies an incremental change to the search index.
  /// - Parameter change: The change to apply
  func applyChange(_ change: SearchModelChange) async {
    await searchIndex.apply(change: change)
  }

  // MARK: Private

  /// Current search task (for cancellation)
  private var searchTask: Task<Void, Never>?

}

// MARK: - SearchDoc to SearchResult Bridge

extension SearchViewModel {

  // MARK: Internal

  /// Returns cached grouped results for UI consumption.
  /// Results are computed once when searchDocResults changes, not on every view render.
  /// - Returns: Array of (section title, results) tuples
  func groupedResults() -> [(section: String, results: [SearchResult])] {
    cachedGroupedResults
  }

  // MARK: Private

  /// Converts SearchDoc results to grouped SearchResult format for UI compatibility.
  /// Groups results by type and applies per-section limits.
  /// Called internally when search results update to populate cachedGroupedResults.
  /// - Parameters:
  ///   - docs: The SearchDoc results to group
  ///   - limit: Maximum items per section (default 20)
  /// - Returns: Array of (section title, results) tuples
  private func groupedResults(from docs: [SearchDoc], limit: Int = 20) -> [(section: String, results: [SearchResult])] {
    // Group docs by type
    let grouped = Dictionary(grouping: docs) { $0.type }

    // Convert to SearchResult sections
    var sections: [(section: String, results: [SearchResult])] = []

    // Process in type priority order: realtor, listing, property, task
    for docType in [SearchDocType.realtor, .listing, .property, .task] {
      guard let typeDocs = grouped[docType], !typeDocs.isEmpty else { continue }

      let sectionTitle = docType.sectionTitle
      let results = typeDocs.prefix(limit).compactMap { SearchResult.from(searchDoc: $0) }

      if !results.isEmpty {
        sections.append((section: sectionTitle, results: results))
      }
    }

    return sections
  }

}

// MARK: - SearchResult Bridge

extension SearchResult {
  /// Creates a SearchResult from a SearchDoc for UI display.
  /// Note: This is a lightweight bridge - the actual entity data is not available,
  /// so navigation will need to be handled differently for SearchDoc-based results.
  static func from(searchDoc doc: SearchDoc) -> SearchResult? {
    // Create a navigation-style result that carries the SearchDoc info
    // The actual navigation handling will be done via the SearchDoc's id and type
    .searchDoc(doc)
  }
}
