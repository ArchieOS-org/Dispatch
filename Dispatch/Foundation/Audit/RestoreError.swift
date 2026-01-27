//
//  RestoreError.swift
//  Dispatch
//
//  Error types for entity restore operations.
//

import Foundation
import Supabase

// MARK: - RestoreError

enum RestoreError: LocalizedError {
  case noDeleteRecord
  case notAuthorized
  case alreadyExists
  case foreignKeyMissing(String)
  case uniqueConflict(String)
  case unknown(String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noDeleteRecord:
      "No deleted record found to restore"
    case .notAuthorized:
      "You are not authorized to restore this item"
    case .alreadyExists:
      "This item already exists and cannot be restored"
    case .foreignKeyMissing(let entity):
      "Cannot restore - the \(entity) this was linked to no longer exists"
    case .uniqueConflict(let field):
      "Cannot restore - a record with this \(field) already exists"
    case .unknown(let message):
      message
    }
  }

  /// Parse a PostgrestError into a typed RestoreError
  static func from(_ postgrestError: PostgrestError) -> RestoreError {
    let message = postgrestError.message

    // Check for prefix-based errors first (most specific)
    if message.hasPrefix("FK_MISSING:") {
      let entity = String(message.dropFirst("FK_MISSING:".count))
      return .foreignKeyMissing(entity.isEmpty ? "related item" : entity)
    }
    if message.hasPrefix("UNIQUE_CONFLICT:") {
      let field = String(message.dropFirst("UNIQUE_CONFLICT:".count))
      return .uniqueConflict(field.isEmpty ? "field" : field)
    }

    // Fall back to contains-based checks for other error types
    if message.contains("NO_DELETE_RECORD") {
      return .noDeleteRecord
    } else if message.contains("NOT_AUTHORIZED") {
      return .notAuthorized
    } else if message.contains("ALREADY_EXISTS") || message.contains("already exists") {
      return .alreadyExists
    }

    return .unknown(message)
  }
}
