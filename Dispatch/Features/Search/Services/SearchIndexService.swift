//
//  SearchIndexService.swift
//  Dispatch
//
//  Actor-based search index with inverted index for O(1) lookups.
//  Supports warm start and incremental updates.
//

import Foundation
import os

// MARK: - SearchIndexService

/// Thread-safe search index using inverted index for efficient lookups.
/// All operations are isolated to prevent data races.
actor SearchIndexService {

  // MARK: Lifecycle

  init() { }

  // MARK: Internal

  /// Readiness state of the index
  enum ReadinessState: Sendable {
    case notStarted
    case building
    case ready
  }

  /// Current readiness state
  private(set) var readiness: ReadinessState = .notStarted

  /// Whether the index is ready for queries
  var isReady: Bool {
    readiness == .ready
  }

  // MARK: - Public API

  /// Builds the full index from initial data. Call once after first frame renders.
  /// Uses Task.yield() periodically to avoid blocking the main thread.
  /// - Parameter data: Initial data bundle containing all entities to index
  func warmStart(with data: InitialSearchData) async {
    let startTime = CFAbsoluteTimeGetCurrent()
    Self.logger.info("warmStart: starting index build")
    Self.logger.debug(
      "warmStart: documents to index - realtors=\(data.realtors.count), listings=\(data.listings.count), properties=\(data.properties.count), tasks=\(data.tasks.count)"
    )

    readiness = .building

    var processedCount = 0

    // Index realtors
    for realtor in data.realtors {
      let doc = SearchDoc.from(realtor: realtor)
      insertDoc(doc)
      processedCount += 1
      if processedCount.isMultiple(of: yieldInterval) {
        await Task.yield()
      }
    }
    Self.logger.debug("warmStart: indexed \(data.realtors.count) realtors")

    // Index listings
    for listing in data.listings {
      let doc = SearchDoc.from(listing: listing)
      insertDoc(doc)
      processedCount += 1
      if processedCount.isMultiple(of: yieldInterval) {
        await Task.yield()
      }
    }
    Self.logger.debug("warmStart: indexed \(data.listings.count) listings")

    // Index properties
    for property in data.properties {
      let doc = SearchDoc.from(property: property)
      insertDoc(doc)
      processedCount += 1
      if processedCount.isMultiple(of: yieldInterval) {
        await Task.yield()
      }
    }
    Self.logger.debug("warmStart: indexed \(data.properties.count) properties")

    // Index tasks
    for task in data.tasks {
      let doc = SearchDoc.from(task: task)
      insertDoc(doc)
      processedCount += 1
      if processedCount.isMultiple(of: yieldInterval) {
        await Task.yield()
      }
    }
    Self.logger.debug("warmStart: indexed \(data.tasks.count) tasks")

    readiness = .ready

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    Self.logger.info("warmStart: complete - \(processedCount) documents indexed in \(duration, format: .fixed(precision: 2))ms")
  }

  /// Applies an incremental change to the index.
  /// - Parameter change: The change to apply (insert, update, or delete)
  func apply(change: SearchModelChange) async {
    switch change {
    case .insert(let doc):
      Self.logger.debug("apply: insert \(doc.type.rawValue) id=\(doc.id)")
      insertDoc(doc)

    case .update(let doc):
      Self.logger.debug("apply: update \(doc.type.rawValue) id=\(doc.id)")
      // Remove old tokens first, then insert new doc
      removeDoc(id: doc.id)
      insertDoc(doc)

    case .delete(let id):
      Self.logger.debug("apply: delete id=\(id)")
      removeDoc(id: id)
    }
  }

  /// Searches the index and returns ranked results.
  /// - Parameters:
  ///   - query: The search query string
  ///   - limit: Maximum number of results to return
  /// - Returns: Array of SearchDoc ranked by relevance
  func search(_ query: String, limit: Int) async -> [SearchDoc] {
    let startTime = CFAbsoluteTimeGetCurrent()
    let normalizedQuery = SearchDoc.normalize(query)
    let queryTokens = SearchDoc.tokenize(query)

    Self.logger.debug("search: query='\(query)' normalized='\(normalizedQuery)' tokens=\(queryTokens.count)")

    // Empty query: return most recent docs with type priority
    if queryTokens.isEmpty {
      let results = recentDocs(limit: limit)
      Self.logger.debug("search: empty query, returning \(results.count) recent docs")
      return results
    }

    // Find candidate documents that contain all query tokens
    var candidateIDs: Set<UUID>?

    for token in queryTokens {
      let matchingIDs = tokenToIDs[token] ?? []
      if let existing = candidateIDs {
        candidateIDs = existing.intersection(matchingIDs)
        Self.logger.debug("search: token '\(token)' intersection -> \(candidateIDs?.count ?? 0) candidates")
      } else {
        candidateIDs = matchingIDs
        Self.logger.debug("search: token '\(token)' initial -> \(matchingIDs.count) candidates")
      }
    }

    var candidates = (candidateIDs ?? []).compactMap { idToDoc[$0] }
    var usedFallback = false

    // Fallback for no intersection matches with query >= 3 chars
    if candidates.isEmpty, query.count >= 3 {
      Self.logger.debug("search: no intersection matches, using fallback search")
      candidates = fallbackSearch(normalizedQuery: normalizedQuery, limit: 500)
      usedFallback = true
    }

    // Rank and return top results
    let ranked = rankResults(
      candidates: candidates,
      normalizedQuery: normalizedQuery,
      queryTokens: queryTokens
    )

    let results = Array(ranked.prefix(limit))
    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    Self.logger.info(
      "search: query='\(query)' results=\(results.count) candidates=\(candidates.count) fallback=\(usedFallback) duration=\(duration, format: .fixed(precision: 2))ms"
    )

    return results
  }

  // MARK: Private

  /// Logger instance - static to avoid actor isolation issues with module-level constants
  private static let logger = Logger(subsystem: "com.dispatch.app", category: "SearchIndex")

  /// Number of yield intervals during warm start (every N docs)
  private let yieldInterval = 100

  // MARK: - Primary Data Structures

  /// Maps document ID to its SearchDoc
  private var idToDoc: [UUID: SearchDoc] = [:]

  /// Maps document ID to its tokens (for efficient update/delete)
  private var idToTokens: [UUID: [String]] = [:]

  /// Inverted index: maps token to set of document IDs containing it
  private var tokenToIDs: [String: Set<UUID>] = [:]

  // MARK: - Private Helpers

  /// Inserts a document into all index structures.
  private func insertDoc(_ doc: SearchDoc) {
    idToDoc[doc.id] = doc

    let tokens = SearchDoc.tokenize(doc.searchKey)
    idToTokens[doc.id] = tokens

    for token in tokens {
      tokenToIDs[token, default: []].insert(doc.id)
    }
  }

  /// Removes a document from all index structures.
  private func removeDoc(id: UUID) {
    guard let tokens = idToTokens[id] else { return }

    // Remove from inverted index
    for token in tokens {
      tokenToIDs[token]?.remove(id)
      if tokenToIDs[token]?.isEmpty == true {
        tokenToIDs.removeValue(forKey: token)
      }
    }

    // Remove from primary maps
    idToTokens.removeValue(forKey: id)
    idToDoc.removeValue(forKey: id)
  }

  /// Returns most recent documents, sorted by type priority then recency.
  private func recentDocs(limit: Int) -> [SearchDoc] {
    let sorted = idToDoc.values.sorted { lhs, rhs in
      if lhs.type != rhs.type {
        return lhs.type < rhs.type
      }
      return lhs.updatedAt > rhs.updatedAt
    }
    return Array(sorted.prefix(limit))
  }

  /// Fallback search using substring matching on most recent documents.
  private func fallbackSearch(normalizedQuery: String, limit: Int) -> [SearchDoc] {
    let recentCandidates = idToDoc.values
      .sorted { $0.updatedAt > $1.updatedAt }
      .prefix(limit)

    return recentCandidates.filter { $0.searchKey.contains(normalizedQuery) }
  }

  /// Ranks candidates according to the contract specification.
  /// Ranking order:
  /// 1. Phrase match (searchKey contains full normalized query)
  /// 2. Token coverage (more matching tokens = higher)
  /// 3. Starts-with boost (primaryNorm starts with any query token)
  /// 4. Type priority (realtor > listing > property > task)
  /// 5. Recency (updatedAt desc)
  /// 6. Stable tie-breaker (primaryText asc)
  private func rankResults(
    candidates: [SearchDoc],
    normalizedQuery: String,
    queryTokens: [String]
  ) -> [SearchDoc] {
    candidates.sorted { lhs, rhs in
      // 1. Phrase match
      let lhsPhrase = lhs.searchKey.contains(normalizedQuery)
      let rhsPhrase = rhs.searchKey.contains(normalizedQuery)
      if lhsPhrase != rhsPhrase {
        return lhsPhrase
      }

      // 2. Token coverage
      let lhsTokens = countMatchingTokens(doc: lhs, queryTokens: queryTokens)
      let rhsTokens = countMatchingTokens(doc: rhs, queryTokens: queryTokens)
      if lhsTokens != rhsTokens {
        return lhsTokens > rhsTokens
      }

      // 3. Starts-with boost
      let lhsStartsWith = hasStartsWithBoost(doc: lhs, queryTokens: queryTokens)
      let rhsStartsWith = hasStartsWithBoost(doc: rhs, queryTokens: queryTokens)
      if lhsStartsWith != rhsStartsWith {
        return lhsStartsWith
      }

      // 4. Type priority (lower rawValue = higher priority)
      if lhs.type != rhs.type {
        return lhs.type < rhs.type
      }

      // 5. Recency (more recent = higher)
      if lhs.updatedAt != rhs.updatedAt {
        return lhs.updatedAt > rhs.updatedAt
      }

      // 6. Stable tie-breaker (alphabetical by primaryText)
      return lhs.primaryText < rhs.primaryText
    }
  }

  /// Counts how many query tokens match the document's tokens.
  private func countMatchingTokens(doc: SearchDoc, queryTokens: [String]) -> Int {
    guard let docTokens = idToTokens[doc.id] else { return 0 }
    let docTokenSet = Set(docTokens)
    return queryTokens.filter { docTokenSet.contains($0) }.count
  }

  /// Checks if the document's primary text starts with any query token.
  private func hasStartsWithBoost(doc: SearchDoc, queryTokens: [String]) -> Bool {
    let primaryTokens = SearchDoc.tokenize(doc.primaryNorm)
    guard let firstPrimaryToken = primaryTokens.first else { return false }

    return queryTokens.contains { queryToken in
      firstPrimaryToken.hasPrefix(queryToken)
    }
  }

}
