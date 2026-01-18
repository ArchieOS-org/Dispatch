//
//  SyncError.swift
//  Dispatch
//
//  Structured sync error with user-facing messages and retry classification.
//  All sync errors should flow through this enum for consistent error handling.
//

import Foundation

// MARK: - SyncError

/// Structured sync error with user-facing messages and retry classification.
/// Use `SyncError.from(_:)` to convert any error to a structured SyncError.
enum SyncError: Error, LocalizedError, Equatable {

  // MARK: - Network Errors (Retryable)

  /// Device has no internet connection
  case noInternet

  /// Network connection was lost during operation
  case connectionLost

  /// Request timed out waiting for response
  case timeout

  /// Generic network error with description
  case networkError(String)

  // MARK: - Permission Errors (Fatal)

  /// Row-level security or permission denied error
  /// - Parameter table: Optional table name for specific messaging
  case permissionDenied(table: String?)

  // MARK: - Validation Errors (Fatal)

  /// Failed to encode entity for upload
  /// - Parameter entity: Name of the entity type that failed encoding
  case encodingFailed(entity: String)

  /// Failed to decode entity from server response
  /// - Parameter entity: Name of the entity type that failed decoding
  case decodingFailed(entity: String)

  /// Data validation failed
  /// - Parameter reason: Human-readable reason for validation failure
  case invalidData(reason: String)

  // MARK: - Server Errors

  /// Server returned an error status code
  /// - Parameter statusCode: HTTP status code from server
  case serverError(statusCode: Int)

  /// Server rate limited the request
  case rateLimited

  // MARK: - Unknown Errors

  /// Unknown error that couldn't be classified
  /// - Parameter error: The underlying error
  case unknown(underlyingError: Error)

  // MARK: Internal

  // MARK: - LocalizedError Conformance

  var errorDescription: String? {
    userFacingMessage
  }

  // MARK: - User-Facing Message

  /// Human-readable error message suitable for display to users.
  /// Messages are friendly, clear, and avoid technical jargon.
  var userFacingMessage: String {
    switch self {
    case .noInternet:
      return "No internet connection."

    case .connectionLost:
      return "Connection lost. Please check your network."

    case .timeout:
      return "Connection timed out."

    case .networkError(let description):
      if description.isEmpty {
        return "Network error."
      }
      return "Network error: \(description)"

    case .permissionDenied(let table):
      if let table {
        return "Permission denied syncing \(tableFriendlyName(table))."
      }
      return "Permission denied during sync."

    case .encodingFailed(let entity):
      return "Failed to prepare \(entity) for sync."

    case .decodingFailed(let entity):
      return "Failed to process \(entity) from server."

    case .invalidData(let reason):
      return "Invalid data: \(reason)"

    case .serverError(let statusCode):
      if statusCode >= 500 {
        return "Server is temporarily unavailable. Please try again later."
      }
      return "Server error (\(statusCode)). Please try again."

    case .rateLimited:
      return "Too many requests. Please wait a moment and try again."

    case .unknown(let underlyingError):
      let description = underlyingError.localizedDescription
      if description.isEmpty || description == "The operation couldn\u{2019}t be completed." {
        return "An unexpected error occurred during sync."
      }
      return "Sync failed: \(description)"
    }
  }

  // MARK: - Retry Classification

  /// Whether this error is potentially recoverable by retrying.
  /// - Returns: `true` if retrying might succeed, `false` if the error is fatal
  var isRetryable: Bool {
    switch self {
    case .noInternet, .connectionLost, .timeout, .networkError:
      // Network errors are transient - retry when connectivity improves
      true
    case .rateLimited:
      // Rate limiting is temporary - retry after backoff
      true
    case .serverError(let statusCode):
      // 5xx errors are server-side issues that may resolve
      // 4xx errors (except rate limiting) indicate client issues
      statusCode >= 500
    case .permissionDenied, .encodingFailed, .decodingFailed, .invalidData:
      // Permission and validation errors won't resolve by retrying
      false
    case .unknown:
      // Unknown errors default to retryable to avoid blocking sync
      // If they persist, they'll eventually be logged/investigated
      true
    }
  }

  // MARK: - Factory Method

  /// Converts any error to a structured SyncError.
  /// Analyzes the error type and content to classify appropriately.
  /// - Parameter error: The error to convert
  /// - Returns: A classified SyncError
  static func from(_ error: Error) -> SyncError {
    // Already a SyncError - return as-is
    if let syncError = error as? SyncError {
      return syncError
    }

    // URLError - network issues
    if let urlError = error as? URLError {
      return fromURLError(urlError)
    }

    // Check error string for known patterns
    let errorString = String(describing: error).lowercased()

    // PostgreSQL permission denied (42501) or RLS violations
    if errorString.contains("42501") || errorString.contains("permission denied") {
      let table = extractTableName(from: errorString)
      return .permissionDenied(table: table)
    }

    // Rate limiting detection
    if errorString.contains("rate limit") || errorString.contains("too many requests") {
      return .rateLimited
    }

    // Encoding/decoding errors
    if error is EncodingError {
      return .encodingFailed(entity: "data")
    }
    if error is DecodingError {
      return .decodingFailed(entity: "data")
    }

    // Fallback to unknown
    return .unknown(underlyingError: error)
  }

  // MARK: - Equatable Conformance

  static func ==(lhs: SyncError, rhs: SyncError) -> Bool {
    switch (lhs, rhs) {
    case (.noInternet, .noInternet),
         (.connectionLost, .connectionLost),
         (.timeout, .timeout),
         (.rateLimited, .rateLimited):
      true
    case (.networkError(let lhsDesc), .networkError(let rhsDesc)):
      lhsDesc == rhsDesc
    case (.permissionDenied(let lhsTable), .permissionDenied(let rhsTable)):
      lhsTable == rhsTable
    case (.encodingFailed(let lhsEntity), .encodingFailed(let rhsEntity)):
      lhsEntity == rhsEntity
    case (.decodingFailed(let lhsEntity), .decodingFailed(let rhsEntity)):
      lhsEntity == rhsEntity
    case (.invalidData(let lhsReason), .invalidData(let rhsReason)):
      lhsReason == rhsReason
    case (.serverError(let lhsCode), .serverError(let rhsCode)):
      lhsCode == rhsCode
    case (.unknown(let lhsError), .unknown(let rhsError)):
      lhsError.localizedDescription == rhsError.localizedDescription
    default:
      false
    }
  }

  // MARK: Private

  // MARK: - Private Helpers

  /// Converts URLError to appropriate SyncError case
  private static func fromURLError(_ urlError: URLError) -> SyncError {
    switch urlError.code {
    case .notConnectedToInternet:
      .noInternet
    case .networkConnectionLost:
      .connectionLost
    case .timedOut:
      .timeout
    case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
      .networkError("Unable to reach server.")
    case .secureConnectionFailed:
      .networkError("Secure connection failed.")
    default:
      .networkError(urlError.localizedDescription)
    }
  }

  /// Extracts table name from error string for specific permission error messages
  private static func extractTableName(from errorString: String) -> String? {
    let knownTables = ["notes", "listings", "tasks", "activities", "users", "properties"]
    for table in knownTables {
      if errorString.contains(table) {
        return table
      }
    }
    return nil
  }
}

// MARK: - Helper Functions

/// Converts database table name to user-friendly display name
private func tableFriendlyName(_ table: String) -> String {
  switch table {
  case "notes":
    "notes"
  case "listings":
    "listings"
  case "tasks":
    "tasks"
  case "activities":
    "activities"
  case "users":
    "user profile"
  case "properties":
    "properties"
  default:
    table
  }
}
