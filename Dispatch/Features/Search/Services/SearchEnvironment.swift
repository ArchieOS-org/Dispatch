//
//  SearchEnvironment.swift
//  Dispatch
//
//  Environment configuration for instant search.
//  Provides shared access to SearchIndexService across the app.
//

import Combine
import Foundation
import SwiftUI

// MARK: - SearchEnvironment

/// Shared environment for search functionality.
/// Owns the SearchIndexService singleton and provides access to views.
@MainActor
final class SearchEnvironment: ObservableObject {

  // MARK: Lifecycle

  init() {
    searchIndex = SearchIndexService()
  }

  // MARK: Internal

  /// The shared search index service
  let searchIndex: SearchIndexService

  /// Whether the index has been warmed up
  @Published var isIndexReady: Bool = false

  /// Warms up the search index with initial data.
  /// Call this after the first frame renders to avoid blocking startup.
  /// - Parameter data: Initial data bundle containing entities to index
  func warmStart(with data: InitialSearchData) async {
    await searchIndex.warmStart(with: data)
    isIndexReady = await searchIndex.isReady
  }

  /// Applies an incremental change to the search index.
  /// - Parameter change: The change to apply
  func applyChange(_ change: SearchModelChange) async {
    await searchIndex.apply(change: change)
  }

  /// Creates a new SearchViewModel connected to this environment's index.
  func makeViewModel() -> SearchViewModel {
    SearchViewModel(searchIndex: searchIndex)
  }

}

// MARK: - SearchEnvironmentKey

private struct SearchEnvironmentKey: EnvironmentKey {
  static let defaultValue: SearchEnvironment? = nil
}

extension EnvironmentValues {
  var searchEnvironment: SearchEnvironment? {
    get { self[SearchEnvironmentKey.self] }
    set { self[SearchEnvironmentKey.self] = newValue }
  }
}
