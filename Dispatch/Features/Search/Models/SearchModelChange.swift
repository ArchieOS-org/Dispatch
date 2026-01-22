//
//  SearchModelChange.swift
//  Dispatch
//
//  Incremental change events for the search index.
//

import Foundation

/// Represents an incremental change to the search index.
/// Used for real-time updates when entities are created, modified, or deleted.
enum SearchModelChange: Sendable {
  /// A new document was created and should be added to the index.
  case insert(SearchDoc)

  /// An existing document was updated and should be re-indexed.
  case update(SearchDoc)

  /// A document was deleted and should be removed from the index.
  case delete(id: UUID)
}
