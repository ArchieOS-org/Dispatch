//
//  RealtimeConnectionState.swift
//  Dispatch
//
//  Tracks the state of realtime channel connections for error recovery.
//

import Foundation

/// Connection state for realtime subscriptions.
/// Parallel to SyncStatus but specific to realtime channel health.
enum RealtimeConnectionState: Equatable {
  /// Realtime is connected and functioning normally.
  case connected

  /// Attempting to reconnect after a failure.
  /// - Parameters:
  ///   - attempt: Current retry attempt (1-indexed).
  ///   - maxAttempts: Maximum number of attempts before degrading.
  case reconnecting(attempt: Int, maxAttempts: Int)

  /// Exceeded max retries. Realtime is degraded but background retries continue.
  /// User should be notified via subtle UI indicator.
  case degraded
}
