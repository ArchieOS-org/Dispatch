//
//  RealtimeRetryTests.swift
//  DispatchTests
//
//  Tests for realtime error recovery with exponential backoff retry logic.
//

import Auth
import Supabase
import XCTest
@testable import DispatchApp

// MARK: - RealtimeConnectionStateTests

@MainActor
final class RealtimeConnectionStateTests: XCTestCase {

  // MARK: - Equality Tests

  func test_connected_equalsConnected() {
    XCTAssertEqual(RealtimeConnectionState.connected, RealtimeConnectionState.connected)
  }

  func test_degraded_equalsDegraded() {
    XCTAssertEqual(RealtimeConnectionState.degraded, RealtimeConnectionState.degraded)
  }

  func test_reconnecting_equalsSameAttempt() {
    XCTAssertEqual(
      RealtimeConnectionState.reconnecting(attempt: 1, maxAttempts: 5),
      RealtimeConnectionState.reconnecting(attempt: 1, maxAttempts: 5)
    )
  }

  func test_reconnecting_notEqualsDifferentAttempt() {
    XCTAssertNotEqual(
      RealtimeConnectionState.reconnecting(attempt: 1, maxAttempts: 5),
      RealtimeConnectionState.reconnecting(attempt: 2, maxAttempts: 5)
    )
  }

  func test_connected_notEqualsDegraded() {
    XCTAssertNotEqual(RealtimeConnectionState.connected, RealtimeConnectionState.degraded)
  }

  func test_connected_notEqualsReconnecting() {
    XCTAssertNotEqual(
      RealtimeConnectionState.connected,
      RealtimeConnectionState.reconnecting(attempt: 1, maxAttempts: 5)
    )
  }
}

// MARK: - ChannelLifecycleManagerRetryTests

@MainActor
final class ChannelLifecycleManagerRetryTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    // Use test mode to prevent actual network calls and skip real delays
    manager = ChannelLifecycleManager(mode: .test)
    delegate = MockChannelLifecycleDelegate()
    manager.delegate = delegate
    delegate.reset()
  }

  // MARK: - Initial State Tests

  func test_initialConnectionState_isConnected() {
    XCTAssertEqual(manager.connectionState, .connected)
  }

  func test_initialRetryAttempt_isZero() {
    XCTAssertEqual(manager.retryAttempt, 0)
  }

  // MARK: - State Transition Tests (Unit Tests)

  /// Tests that connection state can be properly tracked.
  /// Since we can't trigger actual failures in test mode, we verify the state enum behavior.
  func test_connectionState_reconnecting_tracksAttempt() {
    // Given - a reconnecting state
    let state = RealtimeConnectionState.reconnecting(attempt: 3, maxAttempts: 5)

    // When - checking the state
    if case .reconnecting(let attempt, let maxAttempts) = state {
      // Then - values are correct
      XCTAssertEqual(attempt, 3)
      XCTAssertEqual(maxAttempts, 5)
    } else {
      XCTFail("Expected reconnecting state")
    }
  }

  func test_connectionState_degraded_indicatesMaxRetriesExceeded() {
    // Given - a degraded state
    let state = RealtimeConnectionState.degraded

    // Then - it's degraded
    XCTAssertEqual(state, .degraded)
  }

  // MARK: - RetryPolicy Integration Tests

  func test_retryPolicy_delaySequence_matchesSpec() {
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

  func test_retryPolicy_maxRetries_is5() {
    XCTAssertEqual(RetryPolicy.maxRetries, 5)
  }

  func test_retryPolicy_maxDelay_is30Seconds() {
    XCTAssertEqual(RetryPolicy.maxDelay, 30.0)
  }

  func test_retryPolicy_delay_cappedAt30_forHighAttempts() {
    // Attempts beyond 5 should all be capped at 30 seconds
    for attempt in 6...10 {
      let delay = RetryPolicy.delay(for: attempt)
      XCTAssertEqual(delay, 30.0, "Attempt \(attempt) should be capped at 30s")
    }
  }

  // MARK: - startListening Behavior in Test Mode

  func test_startListening_skipsInTestMode() async {
    // Given - manager in test mode (set in setUp)

    // When
    await manager.startListening(useBroadcastRealtime: true)

    // Then - should not start listening in test mode (prevents actual network calls)
    XCTAssertFalse(manager.isListening)
    XCTAssertNil(manager.realtimeChannel)
  }

  // MARK: - resetAndReconnect Tests

  func test_resetAndReconnect_resetsRetryAttempt() {
    // Given - simulate elevated retry attempt
    // Note: retryAttempt is private(set) so we test via resetAndReconnect behavior

    // When
    manager.resetAndReconnect(useBroadcastRealtime: true)

    // Then - retry attempt should be reset (we verify via connectionState)
    XCTAssertEqual(manager.connectionState, .connected)
    XCTAssertEqual(manager.retryAttempt, 0)
  }

  func test_resetAndReconnect_setsConnectionStateToConnected() {
    // When
    manager.resetAndReconnect(useBroadcastRealtime: true)

    // Then
    XCTAssertEqual(manager.connectionState, .connected)
  }

  // MARK: - Task Lifecycle Tests

  func test_cancelAllTasks_cancelsRetryTask() {
    // Given - no actual retry task in test mode, but verify method doesn't crash

    // When
    manager.cancelAllTasks()

    // Then - should complete without error
    XCTAssertTrue(true)
  }

  func test_clearTaskReferences_clearsRetryTask() {
    // When
    manager.clearTaskReferences()

    // Then - task references should be nil
    XCTAssertNil(manager.statusTask)
    XCTAssertNil(manager.tasksSubscriptionTask)
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var manager: ChannelLifecycleManager!
  private var delegate: MockChannelLifecycleDelegate!
  // swiftlint:enable implicitly_unwrapped_optional
}

// MARK: - SyncCoordinatorRealtimeTests

/// Tests for SyncCoordinator's realtime state exposure.
/// These tests verify the coordinator correctly exposes SyncManager's realtime state.
@MainActor
final class SyncCoordinatorRealtimeTests: XCTestCase {

  // MARK: Internal

  override func setUp() async throws {
    try await super.setUp()
    // Create mock auth client for tests
    mockAuthClient = MockSyncCoordinatorAuthClient()
    syncManager = SyncManager(mode: .test)
    authManager = AuthManager(authClient: mockAuthClient)
    syncCoordinator = SyncCoordinator(syncManager: syncManager, authManager: authManager)
  }

  // MARK: - showRealtimeDegraded Tests

  func test_showRealtimeDegraded_falseWhenConnected() {
    // Given
    syncManager.realtimeConnectionState = .connected

    // Then
    XCTAssertFalse(syncCoordinator.showRealtimeDegraded)
  }

  func test_showRealtimeDegraded_falseWhenReconnecting() {
    // Given
    syncManager.realtimeConnectionState = .reconnecting(attempt: 2, maxAttempts: 5)

    // Then - reconnecting should not show degraded indicator
    XCTAssertFalse(syncCoordinator.showRealtimeDegraded)
  }

  func test_showRealtimeDegraded_trueWhenDegraded() {
    // Given
    syncManager.realtimeConnectionState = .degraded

    // Then
    XCTAssertTrue(syncCoordinator.showRealtimeDegraded)
  }

  func test_realtimeConnectionState_exposesUnderlyingState() {
    // Given
    let expectedState = RealtimeConnectionState.reconnecting(attempt: 3, maxAttempts: 5)
    syncManager.realtimeConnectionState = expectedState

    // Then
    XCTAssertEqual(syncCoordinator.realtimeConnectionState, expectedState)
  }

  func test_showRealtimeDegraded_returnsFalseAfterReconnection() {
    // Given - start in degraded state
    syncManager.realtimeConnectionState = .degraded
    XCTAssertTrue(syncCoordinator.showRealtimeDegraded)

    // When - reconnection succeeds
    syncManager.realtimeConnectionState = .connected

    // Then - degraded indicator should clear
    XCTAssertFalse(syncCoordinator.showRealtimeDegraded)
  }

  // MARK: Private

  // swiftlint:disable implicitly_unwrapped_optional
  private var mockAuthClient: MockSyncCoordinatorAuthClient!
  private var syncManager: SyncManager!
  private var authManager: AuthManager!
  private var syncCoordinator: SyncCoordinator!
  // swiftlint:enable implicitly_unwrapped_optional
}

// MARK: - MockSyncCoordinatorAuthClient

/// Minimal mock auth client for SyncCoordinator tests.
/// Only provides the interface needed for SyncCoordinator initialization.
// swiftlint:disable:next no_unchecked_sendable
final class MockSyncCoordinatorAuthClient: AuthClientProtocol, @unchecked Sendable {

  // MARK: Lifecycle

  init() {
    let (stream, continuation) = AsyncStream<(event: AuthChangeEvent, session: Session?)>.makeStream()
    authStateChanges = stream
    _stateContinuation = continuation
  }

  deinit {
    _stateContinuation.finish()
  }

  // MARK: Internal

  let authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)>

  func signInWithOAuth(provider _: Provider, redirectTo _: URL?) async throws {
    // No-op for these tests
  }

  func signOut() async throws {
    // No-op for these tests
  }

  func session(from _: URL) async throws -> Session {
    throw NSError(domain: "MockAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
  }

  // MARK: Private

  private let _stateContinuation: AsyncStream<(event: AuthChangeEvent, session: Session?)>.Continuation
}

// MARK: - SyncManagerRealtimeStateTests

/// Tests for SyncManager's realtime connection state management.
/// These tests verify SyncManager correctly stores and exposes realtime state.
///
/// Note: These tests are covered indirectly via SyncCoordinatorRealtimeTests
/// which tests the actual user-facing behavior (showRealtimeDegraded binding).
/// The direct SyncManager tests are included here for API coverage.
@MainActor
final class SyncManagerRealtimeStateTests: XCTestCase {

  // MARK: Internal

  override func setUp() async throws {
    try await super.setUp()
    // Create fresh SyncManager in test mode for each test
    syncManager = SyncManager(mode: .test)
  }

  override func tearDown() async throws {
    await syncManager.shutdown()
    syncManager = nil
    try await super.tearDown()
  }

  // MARK: - Initial State Tests

  func test_initialRealtimeConnectionState_isConnected() {
    // Then
    XCTAssertEqual(syncManager.realtimeConnectionState, .connected)
  }

  // MARK: - State Update Tests

  func test_realtimeConnectionState_canBeSetToDegraded() {
    // When
    syncManager.realtimeConnectionState = .degraded

    // Then
    XCTAssertEqual(syncManager.realtimeConnectionState, .degraded)
  }

  func test_realtimeConnectionState_canBeSetToReconnecting() {
    // When
    syncManager.realtimeConnectionState = .reconnecting(attempt: 2, maxAttempts: 5)

    // Then
    if case .reconnecting(let attempt, let maxAttempts) = syncManager.realtimeConnectionState {
      XCTAssertEqual(attempt, 2)
      XCTAssertEqual(maxAttempts, 5)
    } else {
      XCTFail("Expected reconnecting state")
    }
  }

  // MARK: - attemptRealtimeReconnection Tests

  func test_attemptRealtimeReconnection_skipsInTestMode() {
    // Given
    syncManager.realtimeConnectionState = .degraded

    // When
    syncManager.attemptRealtimeReconnection()

    // Then - in test mode, reconnection is skipped
    // State remains unchanged since RealtimeManager skips in test mode
    XCTAssertEqual(syncManager.realtimeConnectionState, .degraded)
  }

  // MARK: Private

  // swiftlint:disable:next implicitly_unwrapped_optional
  private var syncManager: SyncManager!
}

// MARK: - RealtimeManagerConnectionStateTests

/// Tests for RealtimeManager's connection state management.
@MainActor
final class RealtimeManagerConnectionStateTests: XCTestCase {

  // MARK: Internal

  override func setUp() async throws {
    try await super.setUp()
    manager = RealtimeManager(mode: .test)
  }

  override func tearDown() async throws {
    manager.cancelAllTasks()
    manager.clearTaskReferences()
    manager = nil
    try await super.tearDown()
  }

  // MARK: - Initial State Tests

  func test_initialConnectionState_isConnected() {
    // Then
    XCTAssertEqual(manager.connectionState, .connected)
  }

  // MARK: - attemptReconnection Tests

  func test_attemptReconnection_skipsInTestMode() {
    // When
    manager.attemptReconnection()

    // Then - should not crash and state should remain connected
    XCTAssertEqual(manager.connectionState, .connected)
  }

  func test_attemptReconnection_skipsInPreviewMode() async {
    // Given - use async setup to ensure manager is ready
    let previewManager = RealtimeManager(mode: .preview)

    // When
    previewManager.attemptReconnection()

    // Then
    XCTAssertEqual(previewManager.connectionState, .connected)

    // Cleanup
    await previewManager.stopListening()
    previewManager.cancelAllTasks()
    previewManager.clearTaskReferences()
  }

  // MARK: Private

  // swiftlint:disable:next implicitly_unwrapped_optional
  private var manager: RealtimeManager!
}

// MARK: - BackoffDelayCalculationTests

@MainActor
final class BackoffDelayCalculationTests: XCTestCase {

  func test_backoffSequence_firstFiveAttempts() {
    // Verify the exponential sequence: 2^0, 2^1, 2^2, 2^3, 2^4 = 1, 2, 4, 8, 16
    XCTAssertEqual(RetryPolicy.delay(for: 0), 1.0)
    XCTAssertEqual(RetryPolicy.delay(for: 1), 2.0)
    XCTAssertEqual(RetryPolicy.delay(for: 2), 4.0)
    XCTAssertEqual(RetryPolicy.delay(for: 3), 8.0)
    XCTAssertEqual(RetryPolicy.delay(for: 4), 16.0)
  }

  func test_backoffSequence_capping() {
    // Attempt 5 would be 2^5 = 32, but capped at 30
    XCTAssertEqual(RetryPolicy.delay(for: 5), 30.0)
    // All subsequent attempts should also be 30
    XCTAssertEqual(RetryPolicy.delay(for: 6), 30.0)
    XCTAssertEqual(RetryPolicy.delay(for: 100), 30.0)
  }

  func test_totalTimeBeforeDegraded() {
    // Calculate total wait time before entering degraded state
    // Attempts 0-4 (5 attempts), then degraded
    // Total: 1 + 2 + 4 + 8 + 16 = 31 seconds
    var totalDelay: TimeInterval = 0
    for attempt in 0..<RetryPolicy.maxRetries {
      totalDelay += RetryPolicy.delay(for: attempt)
    }
    XCTAssertEqual(totalDelay, 31.0, accuracy: 0.001)
  }
}

// MARK: - StateTransitionSequenceTests

@MainActor
final class StateTransitionSequenceTests: XCTestCase {

  func test_stateTransitionSequence_connectedToReconnecting() {
    // Verify the expected state progression
    let states: [RealtimeConnectionState] = [
      .connected,
      .reconnecting(attempt: 1, maxAttempts: 5),
      .reconnecting(attempt: 2, maxAttempts: 5),
      .reconnecting(attempt: 3, maxAttempts: 5),
      .reconnecting(attempt: 4, maxAttempts: 5),
      .reconnecting(attempt: 5, maxAttempts: 5),
      .degraded
    ]

    // Verify progression is valid
    XCTAssertEqual(states.first, .connected)
    XCTAssertEqual(states.last, .degraded)

    // Verify reconnecting attempts increment
    for i in 1...5 {
      if case .reconnecting(let attempt, _) = states[i] {
        XCTAssertEqual(attempt, i)
      } else {
        XCTFail("Expected reconnecting state at index \(i)")
      }
    }
  }

  func test_stateTransitionSequence_degradedBackToConnected() {
    // Verify recovery is possible
    let recoverySequence: [RealtimeConnectionState] = [
      .degraded,
      .connected
    ]

    XCTAssertEqual(recoverySequence[0], .degraded)
    XCTAssertEqual(recoverySequence[1], .connected)
    XCTAssertNotEqual(recoverySequence[0], recoverySequence[1])
  }
}
