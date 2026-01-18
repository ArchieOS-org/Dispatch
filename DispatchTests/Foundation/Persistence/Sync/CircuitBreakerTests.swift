//
//  CircuitBreakerTests.swift
//  DispatchTests
//
//  Unit tests for CircuitBreaker.
//  Tests the circuit breaker pattern for sync retries.
//

import XCTest
@testable import DispatchApp

@MainActor
final class CircuitBreakerTests: XCTestCase {

  // MARK: Internal

  // swiftlint:enable implicitly_unwrapped_optional

  // MARK: - Setup / Teardown

  override func setUp() async throws {
    try await super.setUp()
    currentDate = Date()

    // Create circuit breaker with injectable date provider for deterministic testing
    circuitBreaker = CircuitBreaker(
      failureThreshold: 5,
      initialCooldown: 30,
      maxCooldown: 300,
      dateProvider: { [weak self] in self?.currentDate ?? Date() }
    )
  }

  override func tearDown() async throws {
    circuitBreaker = nil
    currentDate = nil
    try await super.tearDown()
  }

  // MARK: - Initial State Tests

  func test_initialState_isClosed() {
    XCTAssertEqual(circuitBreaker.state, .closed)
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 0)
    XCTAssertEqual(circuitBreaker.tripCount, 0)
    XCTAssertFalse(circuitBreaker.isBlocking)
  }

  func test_initialState_allowsSync() {
    XCTAssertTrue(circuitBreaker.shouldAllowSync())
  }

  // MARK: - Failure Recording Tests

  func test_recordFailure_incrementsFailureCount() {
    circuitBreaker.recordFailure()
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 1)
    XCTAssertEqual(circuitBreaker.state, .closed)
  }

  func test_recordFailure_belowThreshold_staysClosed() {
    // Record failures up to but not exceeding threshold
    for i in 1 ..< 5 {
      circuitBreaker.recordFailure()
      XCTAssertEqual(circuitBreaker.consecutiveFailures, i)
      XCTAssertEqual(circuitBreaker.state, .closed, "Should stay closed after \(i) failures")
    }
  }

  func test_recordFailure_atThreshold_tripsCircuit() {
    // Record exactly threshold failures
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    XCTAssertEqual(circuitBreaker.consecutiveFailures, 5)
    if case .open = circuitBreaker.state {
      // Expected
    } else {
      XCTFail("Circuit should be open after \(circuitBreaker.failureThreshold) failures")
    }
    XCTAssertEqual(circuitBreaker.tripCount, 1)
    XCTAssertTrue(circuitBreaker.isBlocking)
  }

  // MARK: - Success Recording Tests

  func test_recordSuccess_resetsFailureCount() {
    circuitBreaker.recordFailure()
    circuitBreaker.recordFailure()
    circuitBreaker.recordFailure()
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 3)

    circuitBreaker.recordSuccess()
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 0)
    XCTAssertEqual(circuitBreaker.state, .closed)
  }

  func test_recordSuccess_resetsTripCount() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }
    XCTAssertEqual(circuitBreaker.tripCount, 1)

    // Advance time past cooldown and allow probe
    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync() // Transitions to half-open

    // Record success
    circuitBreaker.recordSuccess()
    XCTAssertEqual(circuitBreaker.tripCount, 0)
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 0)
    XCTAssertEqual(circuitBreaker.state, .closed)
  }

  // MARK: - Circuit Blocking Tests

  func test_openCircuit_blocksSyncRequests() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    XCTAssertFalse(circuitBreaker.shouldAllowSync())
    XCTAssertTrue(circuitBreaker.isBlocking)
  }

  func test_closedCircuit_allowsSyncRequests() {
    XCTAssertTrue(circuitBreaker.shouldAllowSync())
    XCTAssertFalse(circuitBreaker.isBlocking)
  }

  // MARK: - Cooldown Tests

  func test_cooldown_transitionsToHalfOpenAfterElapsed() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    // Verify blocking immediately after trip
    XCTAssertFalse(circuitBreaker.shouldAllowSync())

    // Advance time past initial cooldown (30s)
    advanceTime(by: 35)

    // Should now transition to half-open and allow sync
    XCTAssertTrue(circuitBreaker.shouldAllowSync())
    XCTAssertEqual(circuitBreaker.state, .halfOpen)
  }

  func test_cooldown_remainingTime() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    // Check remaining cooldown immediately
    if let remaining = circuitBreaker.remainingCooldown {
      XCTAssertEqual(remaining, 30, accuracy: 1)
    } else {
      XCTFail("Should have remaining cooldown")
    }

    // Advance time by 10 seconds
    advanceTime(by: 10)

    if let remaining = circuitBreaker.remainingCooldown {
      XCTAssertEqual(remaining, 20, accuracy: 1)
    } else {
      XCTFail("Should still have remaining cooldown")
    }
  }

  func test_cooldown_nilWhenClosed() {
    XCTAssertNil(circuitBreaker.remainingCooldown)
  }

  // MARK: - Exponential Cooldown Tests

  func test_exponentialCooldown_doublesEachTrip() {
    // First trip: 30s cooldown
    tripAndVerifyCooldown(expectedCooldown: 30)

    // Recover
    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync() // half-open
    circuitBreaker.recordFailure() // Trip again

    // Second trip: 60s cooldown
    verifyCooldown(expected: 60)

    // Recover
    advanceTime(by: 65)
    _ = circuitBreaker.shouldAllowSync() // half-open
    circuitBreaker.recordFailure() // Trip again

    // Third trip: 120s cooldown
    verifyCooldown(expected: 120)

    // Recover
    advanceTime(by: 125)
    _ = circuitBreaker.shouldAllowSync() // half-open
    circuitBreaker.recordFailure() // Trip again

    // Fourth trip: 240s cooldown
    verifyCooldown(expected: 240)

    // Recover
    advanceTime(by: 245)
    _ = circuitBreaker.shouldAllowSync() // half-open
    circuitBreaker.recordFailure() // Trip again

    // Fifth trip: capped at 300s
    verifyCooldown(expected: 300)
  }

  func test_cooldown_cappedAtMaximum() {
    // Verify that cooldown calculation never exceeds maximum
    // Trip count 0: 30 * 2^0 = 30
    // Trip count 1: 30 * 2^1 = 60
    // Trip count 2: 30 * 2^2 = 120
    // Trip count 3: 30 * 2^3 = 240
    // Trip count 4: 30 * 2^4 = 480 -> capped at 300
    // Trip count 5+: capped at 300

    let expectedCooldowns: [TimeInterval] = [30, 60, 120, 240, 300, 300, 300]

    for (tripCount, expected) in expectedCooldowns.enumerated() {
      let actual = CircuitBreakerPolicy.cooldown(for: tripCount)
      XCTAssertEqual(
        actual,
        expected,
        accuracy: 0.001,
        "Trip count \(tripCount) should have cooldown \(expected)"
      )
    }
  }

  // MARK: - Half-Open State Tests

  func test_halfOpen_allowsSingleProbe() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    // Advance past cooldown
    advanceTime(by: 35)

    // First call transitions to half-open and allows probe
    XCTAssertTrue(circuitBreaker.shouldAllowSync())
    XCTAssertEqual(circuitBreaker.state, .halfOpen)

    // Still allows sync in half-open (probe in progress)
    XCTAssertTrue(circuitBreaker.shouldAllowSync())
  }

  func test_halfOpen_successCloseCircuit() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    // Advance past cooldown and transition to half-open
    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync()
    XCTAssertEqual(circuitBreaker.state, .halfOpen)

    // Record success
    circuitBreaker.recordSuccess()
    XCTAssertEqual(circuitBreaker.state, .closed)
    XCTAssertEqual(circuitBreaker.tripCount, 0)
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 0)
  }

  func test_halfOpen_failureReopensCircuit() {
    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }
    let firstTripCount = circuitBreaker.tripCount

    // Advance past cooldown and transition to half-open
    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync()
    XCTAssertEqual(circuitBreaker.state, .halfOpen)

    // Record failure in half-open state
    circuitBreaker.recordFailure()

    if case .open = circuitBreaker.state {
      // Expected - circuit re-opened
    } else {
      XCTFail("Circuit should re-open after failure in half-open state")
    }
    XCTAssertEqual(circuitBreaker.tripCount, firstTripCount + 1, "Trip count should increase")
  }

  // MARK: - Reset Tests

  func test_reset_restoresInitialState() {
    // Trip the circuit multiple times
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }
    XCTAssertEqual(circuitBreaker.tripCount, 1)

    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync()
    circuitBreaker.recordFailure() // Trip again

    XCTAssertEqual(circuitBreaker.tripCount, 2)

    // Reset
    circuitBreaker.reset()

    XCTAssertEqual(circuitBreaker.state, .closed)
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 0)
    XCTAssertEqual(circuitBreaker.tripCount, 0)
    XCTAssertTrue(circuitBreaker.shouldAllowSync())
  }

  // MARK: - State Change Callback Tests

  func test_stateChangeCallback_calledOnTrip() {
    var callbackStates: [CircuitBreakerState] = []
    circuitBreaker.onStateChange = { state in
      callbackStates.append(state)
    }

    // Trip the circuit
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    XCTAssertEqual(callbackStates.count, 1)
    if case .open = callbackStates.first {
      // Expected
    } else {
      XCTFail("Should have received .open state in callback")
    }
  }

  func test_stateChangeCallback_calledOnHalfOpen() {
    var callbackStates: [CircuitBreakerState] = []

    // Trip first
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    // Now set callback
    circuitBreaker.onStateChange = { state in
      callbackStates.append(state)
    }

    // Advance past cooldown
    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync()

    XCTAssertEqual(callbackStates.count, 1)
    XCTAssertEqual(callbackStates.first, .halfOpen)
  }

  func test_stateChangeCallback_calledOnClose() {
    var callbackStates: [CircuitBreakerState] = []

    // Trip and recover
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }

    advanceTime(by: 35)
    _ = circuitBreaker.shouldAllowSync() // half-open

    // Now set callback
    circuitBreaker.onStateChange = { state in
      callbackStates.append(state)
    }

    circuitBreaker.recordSuccess()

    XCTAssertEqual(callbackStates.count, 1)
    XCTAssertEqual(callbackStates.first, .closed)
  }

  // MARK: - Policy Tests

  func test_policy_failureThreshold() {
    XCTAssertEqual(CircuitBreakerPolicy.failureThreshold, 5)
  }

  func test_policy_initialCooldown() {
    XCTAssertEqual(CircuitBreakerPolicy.initialCooldown, 30)
  }

  func test_policy_maxCooldown() {
    XCTAssertEqual(CircuitBreakerPolicy.maxCooldown, 300)
  }

  func test_policy_cooldownSequence() {
    // Verify exponential backoff: 30, 60, 120, 240, 300 (capped)
    let expected: [TimeInterval] = [30, 60, 120, 240, 300, 300]
    for (tripCount, expectedCooldown) in expected.enumerated() {
      let actual = CircuitBreakerPolicy.cooldown(for: tripCount)
      XCTAssertEqual(
        actual,
        expectedCooldown,
        accuracy: 0.001,
        "Trip \(tripCount) should have cooldown \(expectedCooldown)"
      )
    }
  }

  // MARK: - Coexistence with Per-Entity Retries

  func test_circuitBreaker_independentOfPerEntityRetries() {
    // The circuit breaker tracks aggregate failures across sync() calls.
    // Per-entity retry logic in RetryCoordinator operates independently.
    // This test verifies they don't interfere with each other conceptually.

    // Record 4 failures (below threshold)
    for _ in 1 ... 4 {
      circuitBreaker.recordFailure()
    }
    XCTAssertEqual(circuitBreaker.state, .closed, "Circuit should still be closed")
    XCTAssertTrue(circuitBreaker.shouldAllowSync(), "Should still allow sync")

    // Record success (simulating a sync that eventually succeeded via entity retries)
    circuitBreaker.recordSuccess()
    XCTAssertEqual(circuitBreaker.consecutiveFailures, 0, "Failures should be reset")

    // Now record failures again
    for _ in 1 ... 4 {
      circuitBreaker.recordFailure()
    }
    XCTAssertEqual(
      circuitBreaker.consecutiveFailures,
      4,
      "Should track failures from fresh start"
    )
    XCTAssertEqual(circuitBreaker.state, .closed, "Circuit should still be closed")
  }

  // MARK: Private

  // MARK: - Properties

  // swiftlint:disable implicitly_unwrapped_optional
  private var circuitBreaker: CircuitBreaker!
  private var currentDate: Date!

  // MARK: - Helper Methods

  private func advanceTime(by seconds: TimeInterval) {
    currentDate = currentDate.addingTimeInterval(seconds)
  }

  private func tripAndVerifyCooldown(expectedCooldown: TimeInterval) {
    for _ in 1 ... 5 {
      circuitBreaker.recordFailure()
    }
    verifyCooldown(expected: expectedCooldown)
  }

  private func verifyCooldown(expected: TimeInterval) {
    if let remaining = circuitBreaker.remainingCooldown {
      XCTAssertEqual(remaining, expected, accuracy: 1)
    } else {
      XCTFail("Expected cooldown of \(expected) but got nil")
    }
  }
}
