//
//  SyncQueue.swift
//  Dispatch
//
//  Extracted from SyncManager.swift for cohesion.
//  Manages the sync request coalescing queue and single-consumer loop.
//

import Foundation

// MARK: - SyncQueue

/// Manages coalescing sync requests into a single-consumer loop.
/// Prevents duplicate concurrent syncs while ensuring no requests are lost.
@MainActor
final class SyncQueue {

  // MARK: Lifecycle

  init(mode: SyncRunMode) {
    self.mode = mode
  }

  // MARK: Internal

  /// Callback invoked when a sync should be performed.
  /// The queue manages timing and coalescing; this callback does the actual work.
  var onSyncRequested: (() async -> Void)?

  /// The current sync loop task (exposed for shutdown coordination).
  private(set) var syncLoopTask: Task<Void, Never>?

  #if DEBUG
  /// Allows testing the coalescing loop logic without actual network syncs.
  var _simulateCoalescingInTest = false

  /// Internal counter for verifying preview isolation.
  var _telemetry_syncRequests = 0
  #endif

  /// Whether the sync loop is currently active.
  var isLoopActive: Bool {
    syncLoopTask != nil
  }

  /// Coalescing sync request - replaces "fire and forget" tasks with a single consumer.
  /// Guaranteed to run on MainActor.
  func requestSync() {
    // Strict Preview Guard
    if mode == .preview {
      #if DEBUG
      _telemetry_syncRequests += 1
      #endif
      return
    }

    // Test Mode Guard
    // In .test, syncs must be manually triggered via `await sync()`
    // UNLESS we are specifically verifying the coalescing logic.
    if mode == .test {
      #if DEBUG
      if !_simulateCoalescingInTest {
        return
      }
      #else
      return
      #endif
    }

    // 1. Set Flag
    syncRequested = true

    // 2. Ensure Loop Exists
    if syncLoopTask == nil {
      debugLog.log("Starting sync loop...", category: .sync)
      syncLoopTask = Task {
        // Guaranteed Nil-ing: Clear property on exit (finish or cancel)
        // RULE: cleanup at bottom of scope via MainActor.run. NO defer watcher.

        // Drain Loop
        while !Task.isCancelled {
          // Check logic on MainActor
          let shouldRun = await MainActor.run {
            if self.syncRequested {
              self.syncRequested = false
              return true
            }
            return false
          }

          if !shouldRun { break }

          // Do the work via callback
          await self.onSyncRequested?()
        }

        // Explicit Cleanup: Must happen on MainActor
        await MainActor.run {
          self.syncLoopTask = nil
          debugLog.log("Sync loop exited.", category: .sync)
        }
      }
    } else {
      debugLog.log("Sync request coalesced into existing loop.", category: .sync)
    }
  }

  /// Cancels the sync loop task.
  /// Call this during shutdown to stop the loop.
  func cancelLoop() {
    syncLoopTask?.cancel()
  }

  /// Awaits the sync loop task to complete.
  /// Used during shutdown for deterministic cleanup.
  func awaitLoop() async {
    _ = await syncLoopTask?.result
  }

  /// Clears the sync loop task reference.
  /// Call after awaiting to complete cleanup.
  func clearLoopReference() {
    syncLoopTask = nil
  }

  // MARK: Private

  private let mode: SyncRunMode
  private var syncRequested = false
}
