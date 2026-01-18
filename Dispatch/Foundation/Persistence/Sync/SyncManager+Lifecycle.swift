//
//  SyncManager+Lifecycle.swift
//  Dispatch
//
//  Extracted from SyncManager.swift for cohesion.
//  Contains lifecycle management: shutdown, debug tasks, and timeout helpers.
//

import Foundation

// MARK: - SyncManager + Lifecycle

extension SyncManager {

  /// Deterministic shutdown with strict ordering: Unsubscribe -> Cancel -> Await -> Cleanup.
  /// Prevents deadlocks and ensures test isolation.
  func shutdown() async {
    if isShutdown { return }
    isShutdown = true

    debugLog.log("shutdown() called - starting deterministic teardown", category: .sync)

    // 1. Stop realtime listening (unsubscribe channels)
    await realtimeManager.stopListening()

    // 2. Cancel Tasks (Signal listeners to stop)
    debugLog.log("  Cancelling active tasks...", category: .sync)
    realtimeManager.cancelAllTasks()
    syncQueue.cancelLoop()

    #if DEBUG
    debugHangingTask?.cancel()
    #endif

    // 3. Await Tasks (Quiescence)
    debugLog.log("  Awaiting task quiescence...", category: .sync)

    if mode == .test {
      // Provable Termination: Fail if tasks don't exit
      do {
        try await withTimeout(seconds: 2.0) {
          await self.realtimeManager.awaitAllTasks()
          await self.syncQueue.awaitLoop()

          #if DEBUG
          _ = await self.debugHangingTask?.result
          #endif
        }
      } catch {
        debugLog.error("SyncManager.shutdown() timed out! Tasks stuck.")
        #if DEBUG
        if mode == .test {
          assertionFailure("SyncManager.shutdown() timed out in test mode")
        }
        #endif
      }
    } else {
      // In live/preview, just await (logging ensures visibility)
      await realtimeManager.awaitAllTasks()
      await syncQueue.awaitLoop()

      #if DEBUG
      _ = await debugHangingTask?.result
      #endif
    }

    // 4. Cleanup References
    realtimeManager.clearTaskReferences()
    syncQueue.clearLoopReference()

    #if DEBUG
    debugHangingTask = nil
    #endif

    // Clear observer tokens
    clearObserverTokens()

    debugLog.log("shutdown() complete. SyncManager is quiescent.", category: .sync)
  }

  #if DEBUG
  /// Spawns a dummy task for testing deterministic shutdown.
  /// Cooperative: Sleeps in small chunks to allow cancellation.
  /// Updates `debugHangingTask` so shutdown() can find it.
  func performDebugTask(duration: TimeInterval) {
    debugLog.log("DEBUG: performDebugTask started", category: .sync)
    debugHangingTask = Task { [weak self] in
      let chunk = 0.1
      var elapsed = 0.0
      while elapsed < duration {
        if Task.isCancelled { return }
        try? await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
        elapsed += chunk
      }
      // Self-clearing
      await MainActor.run { [weak self] in
        self?.debugHangingTask = nil
      }
    }
  }
  #endif

  /// Helper for test timeout
  func withTimeout(seconds: TimeInterval, operation: @escaping @Sendable () async -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      // Task 1: Operation
      group.addTask {
        await operation()
      }

      // Task 2: Timer
      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw CancellationError() // Timer won
      }

      // Wait for first completion
      do {
        try await group.next()
        // If operation finished first, cancel timer
        group.cancelAll()
      } catch {
        // If timer finished first (threw), cancel operation and rethrow
        group.cancelAll()
        if self.mode == .test {
          struct TimeoutError: Error { }
          throw TimeoutError()
        } else {
          debugLog.error("Operation timed out after \(seconds)s")
        }
      }
    }
  }
}
