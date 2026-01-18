//
//  CircuitBreaker.swift
//  Dispatch
//
//  Circuit breaker pattern for sync retries.
//  Tracks consecutive failures across all entities and pauses sync when threshold exceeded.
//

import Combine
import Foundation

// MARK: - CircuitBreakerState

/// State machine states for the circuit breaker.
enum CircuitBreakerState: Equatable, Sendable {
  /// Normal operation - sync requests are processed.
  case closed
  /// Circuit tripped - sync requests are blocked until cooldown expires.
  case open(since: Date, cooldownDuration: TimeInterval)
  /// Testing if service has recovered - allows single probe sync.
  case halfOpen

  // MARK: Internal

  var isBlocking: Bool {
    switch self {
    case .closed, .halfOpen:
      false
    case .open:
      true
    }
  }

  var displayName: String {
    switch self {
    case .closed:
      "Closed"
    case .open:
      "Open"
    case .halfOpen:
      "Half-Open"
    }
  }
}

// MARK: - CircuitBreakerPolicy

/// Configuration for circuit breaker behavior.
enum CircuitBreakerPolicy {
  /// Number of consecutive failures before circuit trips.
  static let failureThreshold = 5

  /// Initial cooldown duration after circuit trips (30 seconds).
  static let initialCooldown: TimeInterval = 30

  /// Maximum cooldown duration (5 minutes).
  static let maxCooldown: TimeInterval = 300

  /// Calculate cooldown for a given trip count (0-indexed).
  /// Trip 0 = 30s, Trip 1 = 60s, Trip 2 = 120s, Trip 3 = 240s, Trip 4+ = 300s (capped)
  static func cooldown(for tripCount: Int) -> TimeInterval {
    let multiplier = pow(2.0, Double(tripCount))
    return min(maxCooldown, initialCooldown * multiplier)
  }
}

// MARK: - CircuitBreaker

/// Circuit breaker for sync operations.
/// Tracks consecutive failures and blocks sync attempts when threshold exceeded.
/// Thread-safe via MainActor isolation.
@MainActor
final class CircuitBreaker: ObservableObject {

  // MARK: Lifecycle

  init(
    failureThreshold: Int = 5,
    initialCooldown: TimeInterval = 30,
    maxCooldown: TimeInterval = 300,
    dateProvider: @escaping () -> Date = { Date() }
  ) {
    self.failureThreshold = failureThreshold
    self.initialCooldown = initialCooldown
    self.maxCooldown = maxCooldown
    self.dateProvider = dateProvider
  }

  // MARK: Internal

  /// Current state of the circuit breaker.
  @Published private(set) var state: CircuitBreakerState = .closed

  /// Number of consecutive failures since last success.
  @Published private(set) var consecutiveFailures = 0

  /// Number of times the circuit has tripped (for exponential cooldown).
  @Published private(set) var tripCount = 0

  /// Callback invoked when circuit breaker state changes.
  /// Used to notify SyncManager to update SyncStatus.
  var onStateChange: ((CircuitBreakerState) -> Void)?

  /// Number of consecutive failures required to trip the circuit.
  let failureThreshold: Int

  /// Initial cooldown duration after first trip.
  let initialCooldown: TimeInterval

  /// Maximum cooldown duration.
  let maxCooldown: TimeInterval

  /// Whether the circuit breaker is currently blocking sync attempts.
  /// This is a pure getter with no side effects - use `shouldAllowSync()` for the
  /// method that transitions state when cooldown expires.
  var isBlocking: Bool {
    checkAndTransitionFromOpenIfNeeded()
  }

  /// Time remaining until cooldown expires (nil if not in open state).
  var remainingCooldown: TimeInterval? {
    guard case .open(let since, let cooldownDuration) = state else {
      return nil
    }

    let now = dateProvider()
    let elapsed = now.timeIntervalSince(since)
    let remaining = cooldownDuration - elapsed

    return remaining > 0 ? remaining : 0
  }

  /// Check if sync should proceed. Call before attempting sync.
  /// - Returns: true if sync should proceed, false if blocked.
  func shouldAllowSync() -> Bool {
    switch state {
    case .closed, .halfOpen:
      return true

    case .open:
      // Check if cooldown has elapsed and transition if needed
      if checkAndTransitionFromOpenIfNeeded() {
        if let remaining = remainingCooldown {
          debugLog.log(
            "CircuitBreaker: Blocking sync - \(Int(remaining))s remaining in cooldown",
            category: .sync
          )
        }
        return false
      }
      // Transitioned to halfOpen, allow probe
      return true
    }
  }

  /// Record a sync failure. Call when sync fails.
  func recordFailure() {
    consecutiveFailures += 1

    debugLog.log(
      "CircuitBreaker: Failure recorded (\(consecutiveFailures)/\(failureThreshold))",
      category: .sync
    )

    switch state {
    case .closed:
      if consecutiveFailures >= failureThreshold {
        trip()
      }

    case .halfOpen:
      // Probe failed - circuit trips again with increased cooldown
      trip()

    case .open:
      // Already open - shouldn't happen but log it
      debugLog.log("CircuitBreaker: Failure recorded while open (unexpected)", category: .sync)
    }
  }

  /// Record a sync success. Call when sync succeeds.
  func recordSuccess() {
    debugLog.log("CircuitBreaker: Success recorded - resetting", category: .sync)

    consecutiveFailures = 0
    tripCount = 0
    transitionTo(.closed)
  }

  /// Reset the circuit breaker to initial state.
  /// Use this for manual recovery or testing.
  func reset() {
    debugLog.log("CircuitBreaker: Manual reset", category: .sync)

    consecutiveFailures = 0
    tripCount = 0
    transitionTo(.closed)
  }

  // MARK: Private

  /// Provider for current time (injectable for testing).
  private let dateProvider: () -> Date

  /// Checks if the circuit is in open state and transitions to halfOpen if cooldown has elapsed.
  /// - Returns: true if still blocking (in open state with cooldown not elapsed), false otherwise.
  private func checkAndTransitionFromOpenIfNeeded() -> Bool {
    guard case .open(let since, let cooldownDuration) = state else {
      return false // not in open state
    }

    let elapsed = dateProvider().timeIntervalSince(since)
    if elapsed >= cooldownDuration {
      transitionTo(.halfOpen)
      return false // transitioned to halfOpen, not blocking
    }

    return true // still blocking
  }

  private func trip() {
    let cooldown = calculateCooldown(for: tripCount)
    let now = dateProvider()

    debugLog.log(
      "CircuitBreaker: TRIPPED (trip #\(tripCount + 1), cooldown: \(Int(cooldown))s)",
      category: .sync
    )

    tripCount += 1
    transitionTo(.open(since: now, cooldownDuration: cooldown))
  }

  private func calculateCooldown(for tripCount: Int) -> TimeInterval {
    let multiplier = pow(2.0, Double(tripCount))
    return min(maxCooldown, initialCooldown * multiplier)
  }

  private func transitionTo(_ newState: CircuitBreakerState) {
    guard state != newState else { return }

    let oldState = state
    state = newState

    debugLog.log(
      "CircuitBreaker: State transition \(oldState.displayName) -> \(newState.displayName)",
      category: .sync
    )

    onStateChange?(newState)
  }
}
