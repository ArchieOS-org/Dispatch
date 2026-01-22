//
//  InitialSearchData.swift
//  Dispatch
//
//  Initial data bundle for warm-starting the search index.
//

import Foundation

/// Container for all entity types needed to build the initial search index.
/// NOTE: Activities are explicitly excluded from search scope per contract.
struct InitialSearchData: Sendable {
  /// Users filtered to userType == .realtor
  let realtors: [User]

  /// All listings
  let listings: [Listing]

  /// All properties
  let properties: [Property]

  /// All tasks
  let tasks: [TaskItem]

  /// Total number of entities to index
  var totalCount: Int {
    realtors.count + listings.count + properties.count + tasks.count
  }
}
