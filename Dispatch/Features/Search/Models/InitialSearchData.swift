//
//  InitialSearchData.swift
//  Dispatch
//
//  Initial data bundle for warm-starting the search index.
//

import Foundation

/// Container for all entity types needed to build the initial search index.
/// Uses Sendable DTOs to safely cross actor boundaries from MainActor to SearchIndexService.
/// NOTE: Activities are explicitly excluded from search scope per contract.
struct InitialSearchData: Sendable {
  /// Realtor data extracted from User models (userType == .realtor)
  let realtors: [SearchableRealtor]

  /// Listing data extracted from Listing models
  let listings: [SearchableListing]

  /// Property data extracted from Property models
  let properties: [SearchableProperty]

  /// Task data extracted from TaskItem models
  let tasks: [SearchableTask]

  /// Total number of entities to index
  var totalCount: Int {
    realtors.count + listings.count + properties.count + tasks.count
  }
}
