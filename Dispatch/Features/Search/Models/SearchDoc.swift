//
//  SearchDoc.swift
//  Dispatch
//
//  Search document type and data structure for instant search indexing.
//

import Foundation
import SwiftUI

// MARK: - SearchDocType

/// Priority ranking for search result types.
/// Lower rawValue = higher priority in search results.
/// Core enum is nonisolated and Sendable for use in SearchIndexService actor.
enum SearchDocType: Int, Sendable, Comparable {
  case realtor = 0
  case listing = 1
  case property = 2
  case task = 3

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

// MARK: - SearchDocType UI Properties

/// UI properties isolated to MainActor since they use SwiftUI types (Color).
/// This separation keeps the core enum nonisolated for actor usage.
@MainActor
extension SearchDocType {
  var displayName: String {
    switch self {
    case .realtor: "Realtor"
    case .listing: "Listing"
    case .property: "Property"
    case .task: "Task"
    }
  }

  /// SF Symbol icon for this type
  var icon: String {
    switch self {
    case .realtor: DS.Icons.Entity.realtor
    case .listing: DS.Icons.Entity.listing
    case .property: DS.Icons.Entity.property
    case .task: DS.Icons.Entity.task
    }
  }

  /// Section title for UI grouping
  var sectionTitle: String {
    switch self {
    case .realtor: "Realtors"
    case .listing: "Listings"
    case .property: "Properties"
    case .task: "Tasks"
    }
  }

  /// Accent color for this type
  var accentColor: Color {
    switch self {
    case .realtor: DS.Colors.Section.realtors
    case .listing: DS.Colors.Section.listings
    case .property: DS.Colors.Section.properties
    case .task: DS.Colors.Section.tasks
    }
  }
}

// MARK: - SearchDoc

/// Immutable search document for indexing and ranking.
/// Contains precomputed normalized text for efficient search operations.
struct SearchDoc: Identifiable, Sendable, Equatable, Hashable {

  // MARK: Lifecycle

  init(
    id: UUID,
    type: SearchDocType,
    updatedAt: Date,
    primaryText: String,
    secondaryText: String,
    searchKey: String
  ) {
    self.id = id
    self.type = type
    self.updatedAt = updatedAt
    self.primaryText = primaryText
    self.secondaryText = secondaryText
    self.searchKey = searchKey
    primaryNorm = SearchDoc.normalize(primaryText)
    secondaryNorm = SearchDoc.normalize(secondaryText)
  }

  // MARK: Internal

  let id: UUID
  let type: SearchDocType
  let updatedAt: Date
  let primaryText: String
  let secondaryText: String
  let searchKey: String

  /// Precomputed normalized primary text for ranking
  let primaryNorm: String

  /// Precomputed normalized secondary text for ranking
  let secondaryNorm: String

  // MARK: - Factory Methods

  /// Creates a SearchDoc from a User (realtor only).
  /// - Parameter realtor: The User entity (must have userType == .realtor)
  /// - Returns: A SearchDoc configured for realtor search
  static func from(realtor: User) -> SearchDoc {
    let searchKey = normalize(buildSearchKey(
      realtor.name,
      realtor.email
    ))

    return SearchDoc(
      id: realtor.id,
      type: .realtor,
      updatedAt: realtor.updatedAt,
      primaryText: realtor.name,
      secondaryText: realtor.email,
      searchKey: searchKey
    )
  }

  /// Creates a SearchDoc from a Listing.
  static func from(listing: Listing) -> SearchDoc {
    let secondary = [listing.city, listing.status.displayName]
      .filter { !$0.isEmpty }
      .joined(separator: " - ")

    let searchKey = normalize(buildSearchKey(
      listing.address,
      listing.city,
      listing.postalCode,
      listing.status.rawValue
    ))

    return SearchDoc(
      id: listing.id,
      type: .listing,
      updatedAt: listing.updatedAt,
      primaryText: listing.address,
      secondaryText: secondary,
      searchKey: searchKey
    )
  }

  /// Creates a SearchDoc from a Property.
  static func from(property: Property) -> SearchDoc {
    let secondary = [property.city, property.propertyType.displayName]
      .filter { !$0.isEmpty }
      .joined(separator: " - ")

    let searchKey = normalize(buildSearchKey(
      property.displayAddress,
      property.city,
      property.postalCode
    ))

    return SearchDoc(
      id: property.id,
      type: .property,
      updatedAt: property.updatedAt,
      primaryText: property.displayAddress,
      secondaryText: secondary,
      searchKey: searchKey
    )
  }

  /// Creates a SearchDoc from a TaskItem.
  static func from(task: TaskItem) -> SearchDoc {
    let secondary = task.taskDescription.isEmpty
      ? task.status.displayName
      : task.taskDescription

    let searchKey = normalize(buildSearchKey(
      task.title,
      task.taskDescription,
      task.status.rawValue
    ))

    return SearchDoc(
      id: task.id,
      type: .task,
      updatedAt: task.updatedAt,
      primaryText: task.title,
      secondaryText: secondary,
      searchKey: searchKey
    )
  }

  // MARK: - Normalization

  /// Normalizes a string for search: lowercase, remove diacritics, collapse whitespace.
  static func normalize(_ text: String) -> String {
    text
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .components(separatedBy: .whitespaces)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  /// Tokenizes a string for inverted index: split on non-alphanumerics, drop short tokens.
  static func tokenize(_ text: String) -> [String] {
    let normalized = normalize(text)
    let tokens = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { token in
        if token.isEmpty {
          return false
        }
        // Keep numeric tokens of any length, require 2+ chars for text
        if token.allSatisfy({ $0.isNumber }) {
          return true
        }
        return token.count >= 2
      }
    // Dedupe while preserving order
    var seen = Set<String>()
    return tokens.filter { seen.insert($0).inserted }
  }

  // MARK: Private

  /// Builds a search key from multiple optional/non-optional strings.
  private static func buildSearchKey(_ components: String?...) -> String {
    components
      .compactMap { $0 }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

}

// MARK: - TaskStatus Extension

extension TaskStatus {
  var displayName: String {
    switch self {
    case .open: "Open"
    case .inProgress: "In Progress"
    case .completed: "Completed"
    case .deleted: "Deleted"
    }
  }
}
