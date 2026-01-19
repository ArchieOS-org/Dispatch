//
//  AsyncTestHelpers.swift
//  DispatchTests
//
//  Shared utilities for deterministic async testing.
//  Provides condition-waiting helpers that replace arbitrary Task.sleep calls.
//

import XCTest

// MARK: - AsyncTestHelpers

extension XCTestCase {

  // MARK: - Condition Waiting

  /// Waits for a condition to become true with a timeout.
  /// Uses polling with short sleep intervals instead of arbitrary long sleeps.
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait for the condition (default: 1.0 seconds)
  ///   - pollInterval: Time between condition checks (default: 10ms)
  ///   - condition: Closure that returns true when the condition is met
  /// - Returns: Whether the condition was met before timeout
  @MainActor
  func waitForCondition(
    timeout: TimeInterval = 1.0,
    pollInterval: TimeInterval = 0.01,
    condition: @escaping () -> Bool
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
    }
    return false
  }

  /// Async variant that supports async condition closures.
  ///
  /// - Parameters:
  ///   - timeout: Maximum time to wait for the condition (default: 1.0 seconds)
  ///   - pollInterval: Time between condition checks (default: 10ms)
  ///   - condition: Async closure that returns true when the condition is met
  /// - Returns: Whether the condition was met before timeout
  @MainActor
  func waitForConditionAsync(
    timeout: TimeInterval = 1.0,
    pollInterval: TimeInterval = 0.01,
    condition: @escaping () async -> Bool
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await condition() { return true }
      try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
    }
    return false
  }

  // MARK: - Expectation Helpers

  /// Creates an expectation that fulfills when a condition becomes true.
  /// Useful for callback-based APIs.
  ///
  /// - Parameters:
  ///   - description: Description for the expectation
  ///   - timeout: Maximum time to wait
  ///   - condition: Closure that returns true when ready
  /// - Returns: The expectation (for chaining or additional configuration)
  @MainActor
  func expectCondition(
    _ description: String,
    timeout: TimeInterval = 1.0,
    condition: @escaping () -> Bool
  ) -> XCTestExpectation {
    let expectation = XCTestExpectation(description: description)

    Task { @MainActor in
      let deadline = Date().addingTimeInterval(timeout)
      while Date() < deadline {
        if condition() {
          expectation.fulfill()
          return
        }
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
      }
    }

    return expectation
  }

  // MARK: - Value Waiting

  /// Waits for a value to reach an expected state.
  /// More expressive than raw condition waiting.
  ///
  /// - Parameters:
  ///   - keyPath: Description of what value is being waited for
  ///   - timeout: Maximum time to wait
  ///   - getValue: Closure that returns the current value
  ///   - expected: The expected value
  /// - Returns: Whether the value matched before timeout
  @MainActor
  func waitForValue<T: Equatable>(
    _ keyPath: String,
    timeout: TimeInterval = 1.0,
    getValue: @escaping () -> T,
    toEqual expected: T
  ) async -> Bool {
    let result = await waitForCondition(timeout: timeout) {
      getValue() == expected
    }
    if !result {
      XCTFail("\(keyPath) did not reach expected value \(expected) within \(timeout)s. Actual: \(getValue())")
    }
    return result
  }

  /// Waits for a count to reach at least a minimum value.
  ///
  /// - Parameters:
  ///   - description: Description of what is being counted
  ///   - timeout: Maximum time to wait
  ///   - getCount: Closure that returns the current count
  ///   - minimum: Minimum count to wait for
  /// - Returns: Whether the count reached the minimum before timeout
  @MainActor
  func waitForCount(
    _ description: String,
    timeout: TimeInterval = 1.0,
    getCount: @escaping () -> Int,
    atLeast minimum: Int
  ) async -> Bool {
    _ = description // Used for documentation purposes at call site
    return await waitForCondition(timeout: timeout) {
      getCount() >= minimum
    }
  }
}
