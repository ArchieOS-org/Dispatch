//
//  RetryPolicyTests.swift
//  DispatchTests
//
//  Tests for exponential backoff retry policy.
//

import XCTest
@testable import DispatchApp

final class RetryPolicyTests: XCTestCase {

  // MARK: - RetryPolicy.delay(for:) Tests

  func test_delay_firstAttempt_returns1Second() {
    // Attempt 0 (first retry) should wait 1 second (2^0 = 1)
    let delay = RetryPolicy.delay(for: 0)
    XCTAssertEqual(delay, 1.0, accuracy: 0.001)
  }

  func test_delay_secondAttempt_returns2Seconds() {
    // Attempt 1 should wait 2 seconds (2^1 = 2)
    let delay = RetryPolicy.delay(for: 1)
    XCTAssertEqual(delay, 2.0, accuracy: 0.001)
  }

  func test_delay_thirdAttempt_returns4Seconds() {
    // Attempt 2 should wait 4 seconds (2^2 = 4)
    let delay = RetryPolicy.delay(for: 2)
    XCTAssertEqual(delay, 4.0, accuracy: 0.001)
  }

  func test_delay_fourthAttempt_returns8Seconds() {
    // Attempt 3 should wait 8 seconds (2^3 = 8)
    let delay = RetryPolicy.delay(for: 3)
    XCTAssertEqual(delay, 8.0, accuracy: 0.001)
  }

  func test_delay_fifthAttempt_returns16Seconds() {
    // Attempt 4 should wait 16 seconds (2^4 = 16)
    let delay = RetryPolicy.delay(for: 4)
    XCTAssertEqual(delay, 16.0, accuracy: 0.001)
  }

  func test_delay_cappedAt30Seconds() {
    // Attempt 5 would be 32 seconds, but should be capped at 30
    let delay = RetryPolicy.delay(for: 5)
    XCTAssertEqual(delay, 30.0, accuracy: 0.001)

    // Higher attempts should also be capped at 30
    let delay10 = RetryPolicy.delay(for: 10)
    XCTAssertEqual(delay10, 30.0, accuracy: 0.001)
  }

  func test_maxRetries_is5() {
    XCTAssertEqual(RetryPolicy.maxRetries, 5)
  }

  func test_maxDelay_is30Seconds() {
    XCTAssertEqual(RetryPolicy.maxDelay, 30.0, accuracy: 0.001)
  }

  // MARK: - Backoff Sequence Verification

  func test_backoffSequence_matches_spec() {
    // Per acceptance criteria: 1s, 2s, 4s, 8s, 16s, capped at 30s
    let expectedDelays: [TimeInterval] = [1, 2, 4, 8, 16, 30]

    for (attempt, expectedDelay) in expectedDelays.enumerated() {
      let actualDelay = RetryPolicy.delay(for: attempt)
      XCTAssertEqual(
        actualDelay,
        expectedDelay,
        accuracy: 0.001,
        "Attempt \(attempt) should have delay \(expectedDelay)s, got \(actualDelay)s"
      )
    }
  }
}
