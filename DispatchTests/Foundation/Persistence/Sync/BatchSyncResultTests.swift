//
//  BatchSyncResultTests.swift
//  DispatchTests
//
//  Comprehensive tests for BatchSyncResult struct including:
//  - Basic properties and computed values
//  - Builder pattern functionality
//  - Retry classification methods
//  - Summary generation
//

import XCTest
@testable import DispatchApp

// MARK: - BatchSyncResultTests

final class BatchSyncResultTests: XCTestCase {

  // MARK: - Basic Properties Tests

  func test_init_withDefaults_createsEmptyResult() {
    let result = BatchSyncResult<String>()
    XCTAssertTrue(result.succeeded.isEmpty)
    XCTAssertTrue(result.failed.isEmpty)
    XCTAssertEqual(result.totalCount, 0)
  }

  func test_init_withSucceeded_setsSucceededArray() {
    let result = BatchSyncResult<String>(succeeded: ["A", "B", "C"])
    XCTAssertEqual(result.succeeded, ["A", "B", "C"])
    XCTAssertTrue(result.failed.isEmpty)
    XCTAssertEqual(result.successCount, 3)
  }

  func test_init_withFailed_setsFailedArray() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet),
      ("B", .timeout)
    ]
    let result = BatchSyncResult<String>(succeeded: [], failed: failures)
    XCTAssertTrue(result.succeeded.isEmpty)
    XCTAssertEqual(result.failed.count, 2)
    XCTAssertEqual(result.failureCount, 2)
  }

  func test_init_withBoth_setsBothArrays() {
    let failures: [(entity: String, error: SyncError)] = [("D", .noInternet)]
    let result = BatchSyncResult<String>(succeeded: ["A", "B", "C"], failed: failures)
    XCTAssertEqual(result.successCount, 3)
    XCTAssertEqual(result.failureCount, 1)
    XCTAssertEqual(result.totalCount, 4)
  }

  // MARK: - Static Factory Methods Tests

  func test_success_createsFullySuccessfulResult() {
    let result = BatchSyncResult<String>.success(["A", "B", "C"])
    XCTAssertEqual(result.successCount, 3)
    XCTAssertEqual(result.failureCount, 0)
    XCTAssertTrue(result.isComplete)
    XCTAssertFalse(result.hasFailures)
  }

  func test_singleFailure_createsSingleFailedResult() {
    let result = BatchSyncResult<String>.singleFailure("A", error: .noInternet)
    XCTAssertEqual(result.successCount, 0)
    XCTAssertEqual(result.failureCount, 1)
    XCTAssertFalse(result.isComplete)
    XCTAssertTrue(result.hasFailures)
    XCTAssertEqual(result.failed.first?.entity, "A")
    XCTAssertEqual(result.failed.first?.error, .noInternet)
  }

  func test_empty_createsEmptyResult() {
    let result = BatchSyncResult<String>.empty
    XCTAssertTrue(result.succeeded.isEmpty)
    XCTAssertTrue(result.failed.isEmpty)
    XCTAssertEqual(result.totalCount, 0)
    XCTAssertTrue(result.isComplete)
    XCTAssertFalse(result.hasFailures)
  }

  // MARK: - Computed Properties Tests

  func test_hasFailures_trueWhenFailedNotEmpty() {
    let failures: [(entity: String, error: SyncError)] = [("A", .noInternet)]
    let result = BatchSyncResult<String>(failed: failures)
    XCTAssertTrue(result.hasFailures)
  }

  func test_hasFailures_falseWhenFailedEmpty() {
    let result = BatchSyncResult<String>(succeeded: ["A"])
    XCTAssertFalse(result.hasFailures)
  }

  func test_isComplete_trueWhenNoFailures() {
    let result = BatchSyncResult<String>(succeeded: ["A", "B"])
    XCTAssertTrue(result.isComplete)
  }

  func test_isComplete_falseWhenHasFailures() {
    let failures: [(entity: String, error: SyncError)] = [("A", .noInternet)]
    let result = BatchSyncResult<String>(succeeded: ["B"], failed: failures)
    XCTAssertFalse(result.isComplete)
  }

  func test_errors_returnsAllErrorsFromFailed() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet),
      ("B", .timeout),
      ("C", .permissionDenied(table: "tasks"))
    ]
    let result = BatchSyncResult<String>(failed: failures)

    XCTAssertEqual(result.errors.count, 3)
    XCTAssertTrue(result.errors.contains(.noInternet))
    XCTAssertTrue(result.errors.contains(.timeout))
    XCTAssertTrue(result.errors.contains(.permissionDenied(table: "tasks")))
  }

  // MARK: - Retry Classification Tests

  func test_hasRetryableFailures_trueWhenRetryableErrorExists() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet), // retryable
      ("B", .permissionDenied(table: nil)) // not retryable
    ]
    let result = BatchSyncResult<String>(failed: failures)
    XCTAssertTrue(result.hasRetryableFailures)
  }

  func test_hasRetryableFailures_falseWhenOnlyFatalErrors() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .permissionDenied(table: nil)),
      ("B", .encodingFailed(entity: "Task"))
    ]
    let result = BatchSyncResult<String>(failed: failures)
    XCTAssertFalse(result.hasRetryableFailures)
  }

  func test_hasRetryableFailures_falseWhenNoFailures() {
    let result = BatchSyncResult<String>(succeeded: ["A"])
    XCTAssertFalse(result.hasRetryableFailures)
  }

  func test_retryableFailures_filtersCorrectly() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet), // retryable
      ("B", .permissionDenied(table: nil)), // not retryable
      ("C", .timeout), // retryable
      ("D", .encodingFailed(entity: "Task")) // not retryable
    ]
    let result = BatchSyncResult<String>(failed: failures)

    let retryable = result.retryableFailures
    XCTAssertEqual(retryable.count, 2)
    XCTAssertTrue(retryable.contains { $0.entity == "A" && $0.error == .noInternet })
    XCTAssertTrue(retryable.contains { $0.entity == "C" && $0.error == .timeout })
  }

  func test_fatalFailures_filtersCorrectly() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet), // retryable
      ("B", .permissionDenied(table: nil)), // not retryable
      ("C", .timeout), // retryable
      ("D", .encodingFailed(entity: "Task")) // not retryable
    ]
    let result = BatchSyncResult<String>(failed: failures)

    let fatal = result.fatalFailures
    XCTAssertEqual(fatal.count, 2)
    XCTAssertTrue(fatal.contains { $0.entity == "B" && $0.error == .permissionDenied(table: nil) })
    XCTAssertTrue(fatal.contains { $0.entity == "D" && $0.error == .encodingFailed(entity: "Task") })
  }

  // MARK: - Summary Tests

  func test_summary_allSucceeded() {
    let result = BatchSyncResult<String>(succeeded: ["A", "B", "C"])
    XCTAssertEqual(result.summary, "All 3 entities synced successfully.")
  }

  func test_summary_allFailed() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet),
      ("B", .timeout)
    ]
    let result = BatchSyncResult<String>(failed: failures)
    XCTAssertEqual(result.summary, "All 2 entities failed to sync.")
  }

  func test_summary_mixed() {
    let failures: [(entity: String, error: SyncError)] = [("D", .noInternet)]
    let result = BatchSyncResult<String>(succeeded: ["A", "B", "C"], failed: failures)
    XCTAssertEqual(result.summary, "3 synced, 1 failed.")
  }

  func test_errorSummary_noErrors() {
    let result = BatchSyncResult<String>(succeeded: ["A"])
    XCTAssertEqual(result.errorSummary, "No errors.")
  }

  func test_errorSummary_singleError() {
    let failures: [(entity: String, error: SyncError)] = [("A", .noInternet)]
    let result = BatchSyncResult<String>(failed: failures)
    XCTAssertEqual(result.errorSummary, "- No internet connection.")
  }

  func test_errorSummary_multipleUniqueErrors() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet),
      ("B", .timeout)
    ]
    let result = BatchSyncResult<String>(failed: failures)

    let summary = result.errorSummary
    XCTAssertTrue(summary.contains("- No internet connection."))
    XCTAssertTrue(summary.contains("- Connection timed out."))
  }

  func test_errorSummary_duplicateErrors_showsCount() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet),
      ("B", .noInternet),
      ("C", .noInternet)
    ]
    let result = BatchSyncResult<String>(failed: failures)
    XCTAssertEqual(result.errorSummary, "- No internet connection. (3x)")
  }

  func test_errorSummary_mixedDuplicates() {
    let failures: [(entity: String, error: SyncError)] = [
      ("A", .noInternet),
      ("B", .noInternet),
      ("C", .timeout)
    ]
    let result = BatchSyncResult<String>(failed: failures)

    let summary = result.errorSummary
    XCTAssertTrue(summary.contains("- No internet connection. (2x)"))
    XCTAssertTrue(summary.contains("- Connection timed out."))
  }

  // MARK: - Builder Pattern Tests

  func test_builder_empty_buildsEmptyResult() {
    var builder = BatchSyncResult<String>.Builder()
    let result = builder.build()
    XCTAssertTrue(result.succeeded.isEmpty)
    XCTAssertTrue(result.failed.isEmpty)
  }

  func test_builder_addSuccess_addsToSucceeded() {
    var builder = BatchSyncResult<String>.Builder()
    builder.addSuccess("A")
    builder.addSuccess("B")

    let result = builder.build()
    XCTAssertEqual(result.succeeded, ["A", "B"])
    XCTAssertTrue(result.failed.isEmpty)
  }

  func test_builder_addSuccesses_addsMultiple() {
    var builder = BatchSyncResult<String>.Builder()
    builder.addSuccesses(["A", "B", "C"])

    let result = builder.build()
    XCTAssertEqual(result.succeeded, ["A", "B", "C"])
  }

  func test_builder_addFailure_addsToFailed() {
    var builder = BatchSyncResult<String>.Builder()
    builder.addFailure("A", error: .noInternet)
    builder.addFailure("B", error: .timeout)

    let result = builder.build()
    XCTAssertTrue(result.succeeded.isEmpty)
    XCTAssertEqual(result.failed.count, 2)
    XCTAssertEqual(result.failed[0].entity, "A")
    XCTAssertEqual(result.failed[0].error, .noInternet)
    XCTAssertEqual(result.failed[1].entity, "B")
    XCTAssertEqual(result.failed[1].error, .timeout)
  }

  func test_builder_mixedSuccessAndFailure() {
    var builder = BatchSyncResult<String>.Builder()
    builder.addSuccess("A")
    builder.addFailure("B", error: .noInternet)
    builder.addSuccesses(["C", "D"])
    builder.addFailure("E", error: .timeout)

    let result = builder.build()
    XCTAssertEqual(result.succeeded, ["A", "C", "D"])
    XCTAssertEqual(result.failed.count, 2)
    XCTAssertEqual(result.successCount, 3)
    XCTAssertEqual(result.failureCount, 2)
    XCTAssertEqual(result.totalCount, 5)
  }

  func test_builder_canBuildMultipleTimes() {
    var builder = BatchSyncResult<String>.Builder()
    builder.addSuccess("A")

    let result1 = builder.build()
    builder.addSuccess("B")
    let result2 = builder.build()

    // Builder retains state, so second build includes both
    XCTAssertEqual(result1.successCount, 1)
    XCTAssertEqual(result2.successCount, 2)
  }

  // MARK: - Generic Type Tests

  func test_worksWithCustomTypes() {
    struct TestEntity: Equatable {
      let id: Int
      let name: String
    }

    let entity1 = TestEntity(id: 1, name: "First")
    let entity2 = TestEntity(id: 2, name: "Second")
    let entity3 = TestEntity(id: 3, name: "Third")

    let failures: [(entity: TestEntity, error: SyncError)] = [(entity3, .timeout)]
    let result = BatchSyncResult<TestEntity>(succeeded: [entity1, entity2], failed: failures)

    XCTAssertEqual(result.successCount, 2)
    XCTAssertEqual(result.failureCount, 1)
    XCTAssertEqual(result.failed.first?.entity, entity3)
  }

  func test_worksWithUUID() {
    let id1 = UUID()
    let id2 = UUID()
    let id3 = UUID()

    let failures: [(entity: UUID, error: SyncError)] = [(id3, .permissionDenied(table: "tasks"))]
    let result = BatchSyncResult<UUID>(succeeded: [id1, id2], failed: failures)

    XCTAssertEqual(result.totalCount, 3)
    XCTAssertTrue(result.succeeded.contains(id1))
    XCTAssertTrue(result.succeeded.contains(id2))
    XCTAssertEqual(result.failed.first?.entity, id3)
  }
}
