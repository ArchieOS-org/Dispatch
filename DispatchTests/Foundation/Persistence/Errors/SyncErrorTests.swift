//
//  SyncErrorTests.swift
//  DispatchTests
//
//  Comprehensive tests for SyncError enum including:
//  - User-facing message correctness for all cases
//  - Error classification (isRetryable) accuracy
//  - Factory method (from:) error conversion
//  - Equatable conformance
//

import XCTest
@testable import DispatchApp

// MARK: - SyncErrorTests

final class SyncErrorTests: XCTestCase {

  // MARK: - User-Facing Message Tests

  func test_noInternet_hasCorrectMessage() {
    let error = SyncError.noInternet
    XCTAssertEqual(error.userFacingMessage, "No internet connection.")
  }

  func test_connectionLost_hasCorrectMessage() {
    let error = SyncError.connectionLost
    XCTAssertEqual(error.userFacingMessage, "Connection lost. Please check your network.")
  }

  func test_timeout_hasCorrectMessage() {
    let error = SyncError.timeout
    XCTAssertEqual(error.userFacingMessage, "Connection timed out.")
  }

  func test_networkError_withDescription_hasCorrectMessage() {
    let error = SyncError.networkError("Unable to reach server.")
    XCTAssertEqual(error.userFacingMessage, "Network error: Unable to reach server.")
  }

  func test_networkError_emptyDescription_hasCorrectMessage() {
    let error = SyncError.networkError("")
    XCTAssertEqual(error.userFacingMessage, "Network error.")
  }

  func test_permissionDenied_withTable_hasCorrectMessage() {
    let error = SyncError.permissionDenied(table: "tasks")
    XCTAssertEqual(error.userFacingMessage, "Permission denied syncing tasks.")
  }

  func test_permissionDenied_withUsersTable_hasCorrectMessage() {
    let error = SyncError.permissionDenied(table: "users")
    XCTAssertEqual(error.userFacingMessage, "Permission denied syncing user profile.")
  }

  func test_permissionDenied_withoutTable_hasCorrectMessage() {
    let error = SyncError.permissionDenied(table: nil)
    XCTAssertEqual(error.userFacingMessage, "Permission denied during sync.")
  }

  func test_encodingFailed_hasCorrectMessage() {
    let error = SyncError.encodingFailed(entity: "TaskItem")
    XCTAssertEqual(error.userFacingMessage, "Failed to prepare TaskItem for sync.")
  }

  func test_decodingFailed_hasCorrectMessage() {
    let error = SyncError.decodingFailed(entity: "Activity")
    XCTAssertEqual(error.userFacingMessage, "Failed to process Activity from server.")
  }

  func test_invalidData_hasCorrectMessage() {
    let error = SyncError.invalidData(reason: "Missing required field")
    XCTAssertEqual(error.userFacingMessage, "Invalid data: Missing required field")
  }

  func test_serverError_5xx_hasCorrectMessage() {
    let error = SyncError.serverError(statusCode: 503)
    XCTAssertEqual(error.userFacingMessage, "Server is temporarily unavailable. Please try again later.")
  }

  func test_serverError_4xx_hasCorrectMessage() {
    let error = SyncError.serverError(statusCode: 400)
    XCTAssertEqual(error.userFacingMessage, "Server error (400). Please try again.")
  }

  func test_rateLimited_hasCorrectMessage() {
    let error = SyncError.rateLimited
    XCTAssertEqual(error.userFacingMessage, "Too many requests. Please wait a moment and try again.")
  }

  func test_unknown_withLocalizedError_hasCorrectMessage() {
    let underlying = SyncErrorMockLocalizedError(description: "Custom error occurred")
    let error = SyncError.unknown(underlyingError: underlying)
    XCTAssertEqual(error.userFacingMessage, "Sync failed: Custom error occurred")
  }

  func test_unknown_withEmptyDescription_hasCorrectMessage() {
    let underlying = SyncErrorMockEmptyError()
    let error = SyncError.unknown(underlyingError: underlying)
    XCTAssertEqual(error.userFacingMessage, "An unexpected error occurred during sync.")
  }

  // MARK: - LocalizedError Conformance Tests

  func test_errorDescription_matchesUserFacingMessage() {
    let testCases: [SyncError] = [
      .noInternet,
      .connectionLost,
      .timeout,
      .networkError("Test"),
      .permissionDenied(table: "tasks"),
      .encodingFailed(entity: "Test"),
      .decodingFailed(entity: "Test"),
      .invalidData(reason: "Test"),
      .serverError(statusCode: 500),
      .rateLimited,
      .unknown(underlyingError: SyncErrorMockLocalizedError(description: "Test"))
    ]

    for error in testCases {
      XCTAssertEqual(
        error.errorDescription,
        error.userFacingMessage,
        "errorDescription should match userFacingMessage for \(error)"
      )
    }
  }

  // MARK: - isRetryable Classification Tests

  func test_noInternet_isRetryable() {
    XCTAssertTrue(SyncError.noInternet.isRetryable)
  }

  func test_connectionLost_isRetryable() {
    XCTAssertTrue(SyncError.connectionLost.isRetryable)
  }

  func test_timeout_isRetryable() {
    XCTAssertTrue(SyncError.timeout.isRetryable)
  }

  func test_networkError_isRetryable() {
    XCTAssertTrue(SyncError.networkError("Test").isRetryable)
  }

  func test_rateLimited_isRetryable() {
    XCTAssertTrue(SyncError.rateLimited.isRetryable)
  }

  func test_serverError_5xx_isRetryable() {
    XCTAssertTrue(SyncError.serverError(statusCode: 500).isRetryable)
    XCTAssertTrue(SyncError.serverError(statusCode: 502).isRetryable)
    XCTAssertTrue(SyncError.serverError(statusCode: 503).isRetryable)
  }

  func test_serverError_4xx_isNotRetryable() {
    XCTAssertFalse(SyncError.serverError(statusCode: 400).isRetryable)
    XCTAssertFalse(SyncError.serverError(statusCode: 401).isRetryable)
    XCTAssertFalse(SyncError.serverError(statusCode: 404).isRetryable)
  }

  func test_permissionDenied_isNotRetryable() {
    XCTAssertFalse(SyncError.permissionDenied(table: "tasks").isRetryable)
    XCTAssertFalse(SyncError.permissionDenied(table: nil).isRetryable)
  }

  func test_encodingFailed_isNotRetryable() {
    XCTAssertFalse(SyncError.encodingFailed(entity: "Task").isRetryable)
  }

  func test_decodingFailed_isNotRetryable() {
    XCTAssertFalse(SyncError.decodingFailed(entity: "Task").isRetryable)
  }

  func test_invalidData_isNotRetryable() {
    XCTAssertFalse(SyncError.invalidData(reason: "Test").isRetryable)
  }

  func test_unknown_isRetryable() {
    // Unknown errors default to retryable to avoid blocking sync
    let underlying = SyncErrorMockLocalizedError(description: "Test")
    XCTAssertTrue(SyncError.unknown(underlyingError: underlying).isRetryable)
  }

  // MARK: - Factory Method (from:) Tests

  func test_from_withSyncError_returnsSameError() {
    let original = SyncError.noInternet
    let converted = SyncError.from(original)
    XCTAssertEqual(converted, original)
  }

  func test_from_withURLError_notConnectedToInternet() {
    let urlError = URLError(.notConnectedToInternet)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .noInternet)
  }

  func test_from_withURLError_networkConnectionLost() {
    let urlError = URLError(.networkConnectionLost)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .connectionLost)
  }

  func test_from_withURLError_timedOut() {
    let urlError = URLError(.timedOut)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .timeout)
  }

  func test_from_withURLError_cannotFindHost() {
    let urlError = URLError(.cannotFindHost)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .networkError("Unable to reach server."))
  }

  func test_from_withURLError_cannotConnectToHost() {
    let urlError = URLError(.cannotConnectToHost)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .networkError("Unable to reach server."))
  }

  func test_from_withURLError_dnsLookupFailed() {
    let urlError = URLError(.dnsLookupFailed)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .networkError("Unable to reach server."))
  }

  func test_from_withURLError_secureConnectionFailed() {
    let urlError = URLError(.secureConnectionFailed)
    let syncError = SyncError.from(urlError)
    XCTAssertEqual(syncError, .networkError("Secure connection failed."))
  }

  func test_from_withURLError_genericError() {
    let urlError = URLError(.badURL)
    let syncError = SyncError.from(urlError)
    // Should be a networkError with the localized description
    if case .networkError = syncError {
      // Success - it's a network error
    } else {
      XCTFail("Expected networkError, got \(syncError)")
    }
  }

  func test_from_withPostgresError_42501() {
    let mockError = SyncErrorMockPostgresError(code: "42501", message: "permission denied for table tasks")
    let syncError = SyncError.from(mockError)
    XCTAssertEqual(syncError, .permissionDenied(table: "tasks"))
  }

  func test_from_withPostgresError_permissionDeniedText() {
    let mockError = SyncErrorMockStringError(description: "permission denied for table notes")
    let syncError = SyncError.from(mockError)
    XCTAssertEqual(syncError, .permissionDenied(table: "notes"))
  }

  func test_from_withRateLimitError() {
    let mockError = SyncErrorMockStringError(description: "rate limit exceeded")
    let syncError = SyncError.from(mockError)
    XCTAssertEqual(syncError, .rateLimited)
  }

  func test_from_withTooManyRequestsError() {
    let mockError = SyncErrorMockStringError(description: "too many requests")
    let syncError = SyncError.from(mockError)
    XCTAssertEqual(syncError, .rateLimited)
  }

  func test_from_withEncodingError() {
    let encodingError = EncodingError.invalidValue(
      "test",
      EncodingError.Context(codingPath: [], debugDescription: "Test encoding error")
    )
    let syncError = SyncError.from(encodingError)
    XCTAssertEqual(syncError, .encodingFailed(entity: "data"))
  }

  func test_from_withDecodingError() {
    let decodingError = DecodingError.dataCorrupted(
      DecodingError.Context(codingPath: [], debugDescription: "Test decoding error")
    )
    let syncError = SyncError.from(decodingError)
    XCTAssertEqual(syncError, .decodingFailed(entity: "data"))
  }

  func test_from_withGenericError_returnsUnknown() {
    let genericError = SyncErrorMockLocalizedError(description: "Something went wrong")
    let syncError = SyncError.from(genericError)
    if case .unknown(let underlying) = syncError {
      XCTAssertEqual(underlying.localizedDescription, "Something went wrong")
    } else {
      XCTFail("Expected unknown error, got \(syncError)")
    }
  }

  // MARK: - Equatable Conformance Tests

  func test_equatable_noInternet() {
    XCTAssertEqual(SyncError.noInternet, SyncError.noInternet)
    XCTAssertNotEqual(SyncError.noInternet, SyncError.connectionLost)
  }

  func test_equatable_connectionLost() {
    XCTAssertEqual(SyncError.connectionLost, SyncError.connectionLost)
    XCTAssertNotEqual(SyncError.connectionLost, SyncError.timeout)
  }

  func test_equatable_timeout() {
    XCTAssertEqual(SyncError.timeout, SyncError.timeout)
    XCTAssertNotEqual(SyncError.timeout, SyncError.noInternet)
  }

  func test_equatable_rateLimited() {
    XCTAssertEqual(SyncError.rateLimited, SyncError.rateLimited)
    XCTAssertNotEqual(SyncError.rateLimited, SyncError.timeout)
  }

  func test_equatable_networkError() {
    XCTAssertEqual(SyncError.networkError("Test"), SyncError.networkError("Test"))
    XCTAssertNotEqual(SyncError.networkError("Test"), SyncError.networkError("Other"))
  }

  func test_equatable_permissionDenied() {
    XCTAssertEqual(SyncError.permissionDenied(table: "tasks"), SyncError.permissionDenied(table: "tasks"))
    XCTAssertNotEqual(SyncError.permissionDenied(table: "tasks"), SyncError.permissionDenied(table: "notes"))
    XCTAssertNotEqual(SyncError.permissionDenied(table: "tasks"), SyncError.permissionDenied(table: nil))
  }

  func test_equatable_encodingFailed() {
    XCTAssertEqual(SyncError.encodingFailed(entity: "Task"), SyncError.encodingFailed(entity: "Task"))
    XCTAssertNotEqual(SyncError.encodingFailed(entity: "Task"), SyncError.encodingFailed(entity: "Activity"))
  }

  func test_equatable_decodingFailed() {
    XCTAssertEqual(SyncError.decodingFailed(entity: "Task"), SyncError.decodingFailed(entity: "Task"))
    XCTAssertNotEqual(SyncError.decodingFailed(entity: "Task"), SyncError.decodingFailed(entity: "Activity"))
  }

  func test_equatable_invalidData() {
    XCTAssertEqual(SyncError.invalidData(reason: "Test"), SyncError.invalidData(reason: "Test"))
    XCTAssertNotEqual(SyncError.invalidData(reason: "Test"), SyncError.invalidData(reason: "Other"))
  }

  func test_equatable_serverError() {
    XCTAssertEqual(SyncError.serverError(statusCode: 500), SyncError.serverError(statusCode: 500))
    XCTAssertNotEqual(SyncError.serverError(statusCode: 500), SyncError.serverError(statusCode: 503))
  }

  func test_equatable_unknown() {
    let error1 = SyncErrorMockLocalizedError(description: "Error 1")
    let error2 = SyncErrorMockLocalizedError(description: "Error 1")
    let error3 = SyncErrorMockLocalizedError(description: "Error 2")

    // Uses localized description for comparison
    XCTAssertEqual(SyncError.unknown(underlyingError: error1), SyncError.unknown(underlyingError: error2))
    XCTAssertNotEqual(SyncError.unknown(underlyingError: error1), SyncError.unknown(underlyingError: error3))
  }

  // MARK: - Table Name Extraction Tests

  func test_from_extractsTableName_tasks() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table tasks")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: "tasks"))
  }

  func test_from_extractsTableName_activities() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table activities")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: "activities"))
  }

  func test_from_extractsTableName_listings() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table listings")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: "listings"))
  }

  func test_from_extractsTableName_notes() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table notes")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: "notes"))
  }

  func test_from_extractsTableName_users() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table users")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: "users"))
  }

  func test_from_extractsTableName_properties() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table properties")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: "properties"))
  }

  func test_from_unknownTable_returnsNilTable() {
    let error = SyncErrorMockStringError(description: "42501: permission denied for table unknown_table")
    let syncError = SyncError.from(error)
    XCTAssertEqual(syncError, .permissionDenied(table: nil))
  }
}

// MARK: - SyncErrorMockLocalizedError

// These are namespaced to avoid conflicts with similar mocks in other test files

private struct SyncErrorMockLocalizedError: Error, LocalizedError {
  let description: String
  var errorDescription: String? { description }
}

// MARK: - SyncErrorMockEmptyError

private struct SyncErrorMockEmptyError: Error, LocalizedError {
  var errorDescription: String? { "" }
}

// MARK: - SyncErrorMockStringError

private struct SyncErrorMockStringError: Error, CustomStringConvertible {
  let description: String
}

// MARK: - SyncErrorMockPostgresError

private struct SyncErrorMockPostgresError: Error, CustomStringConvertible {
  let code: String
  let message: String

  var description: String {
    "PostgrestError(code: \(code), message: \(message))"
  }
}
