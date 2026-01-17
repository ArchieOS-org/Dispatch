//
//  BackendError.swift
//  SharedBackend
//
//  Shared error types for backend operations.
//

import Foundation

/// Errors that can occur during backend operations
public enum BackendError: LocalizedError, Sendable {
  /// Invalid configuration (e.g., malformed URL)
  case invalidConfiguration(String)

  /// Authentication required but user is not logged in
  case notAuthenticated

  /// User does not have permission for this operation
  case unauthorized

  /// Resource not found
  case notFound(String)

  /// Network connectivity issue
  case networkError(Error)

  /// Server returned an error
  case serverError(Int, String)

  /// Failed to encode/decode data
  case codingError(Error)

  /// Generic error with message
  case generic(String)

  public var errorDescription: String? {
    switch self {
    case .invalidConfiguration(let message):
      "Invalid configuration: \(message)"
    case .notAuthenticated:
      "Authentication required. Please sign in."
    case .unauthorized:
      "You do not have permission for this operation."
    case .notFound(let resource):
      "\(resource) not found."
    case .networkError(let error):
      "Network error: \(error.localizedDescription)"
    case .serverError(let code, let message):
      "Server error (\(code)): \(message)"
    case .codingError(let error):
      "Data error: \(error.localizedDescription)"
    case .generic(let message):
      message
    }
  }
}
