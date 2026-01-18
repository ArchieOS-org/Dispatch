//
//  SyncQueueTests.swift
//  DispatchTests
//
//  Unit tests for SyncQueue extracted from SyncManager.
//  Tests coalescing behavior and loop management in isolation.
//

import XCTest
@testable import DispatchApp

@MainActor
final class SyncQueueTests: XCTestCase {

  // MARK: - Initialization Tests

  func test_init_createsInactiveQueue() async {
    let queue = SyncQueue(mode: .test)

    XCTAssertFalse(queue.isLoopActive, "Queue should start inactive")
    XCTAssertNil(queue.syncLoopTask, "No task should exist initially")
  }

  func test_init_previewMode_incrementsTelemetry() async {
    let queue = SyncQueue(mode: .preview)

    #if DEBUG
    XCTAssertEqual(queue._telemetry_syncRequests, 0)
    queue.requestSync()
    XCTAssertEqual(queue._telemetry_syncRequests, 1)
    queue.requestSync()
    XCTAssertEqual(queue._telemetry_syncRequests, 2)
    #endif
  }

  // MARK: - Request Coalescing Tests

  func test_requestSync_previewMode_noLoopStarted() async {
    let queue = SyncQueue(mode: .preview)

    queue.requestSync()

    XCTAssertFalse(queue.isLoopActive, "Preview mode should not start loop")
    XCTAssertNil(queue.syncLoopTask)
  }

  func test_requestSync_testMode_noLoopWithoutSimulation() async {
    let queue = SyncQueue(mode: .test)

    queue.requestSync()

    XCTAssertFalse(queue.isLoopActive, "Test mode should not start loop without simulation flag")
  }

  #if DEBUG
  func test_requestSync_testModeWithSimulation_startsLoop() async throws {
    let queue = SyncQueue(mode: .test)
    queue._simulateCoalescingInTest = true

    var syncCount = 0
    queue.onSyncRequested = {
      syncCount += 1
    }

    queue.requestSync()

    // Wait for loop to process
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms

    // Loop should have started and processed at least once
    XCTAssertGreaterThanOrEqual(syncCount, 1)

    // Cleanup
    queue.cancelLoop()
    await queue.awaitLoop()
  }
  #endif

  // MARK: - Loop Lifecycle Tests

  func test_cancelLoop_stopsActiveLoop() async throws {
    #if DEBUG
    let queue = SyncQueue(mode: .test)
    queue._simulateCoalescingInTest = true

    var syncCount = 0
    queue.onSyncRequested = {
      syncCount += 1
      // Add delay to keep loop alive
      try? await Task.sleep(nanoseconds: 100_000_000)
    }

    queue.requestSync()

    // Wait briefly then cancel
    try await Task.sleep(nanoseconds: 20_000_000)
    queue.cancelLoop()
    await queue.awaitLoop()

    // Loop should be inactive after cancel
    XCTAssertFalse(queue.isLoopActive)
    #else
    throw XCTSkip("Requires DEBUG mode")
    #endif
  }

  func test_clearLoopReference_clearsTask() async throws {
    #if DEBUG
    let queue = SyncQueue(mode: .test)
    queue._simulateCoalescingInTest = true
    queue.onSyncRequested = { }

    queue.requestSync()

    // Wait for loop to start
    try await Task.sleep(nanoseconds: 20_000_000)

    // Cancel and await
    queue.cancelLoop()
    await queue.awaitLoop()

    // Clear reference
    queue.clearLoopReference()

    XCTAssertNil(queue.syncLoopTask)
    #else
    throw XCTSkip("Requires DEBUG mode")
    #endif
  }

  // MARK: - Callback Tests

  func test_onSyncRequested_calledWhenSyncRequested() async {
    #if DEBUG
    let queue = SyncQueue(mode: .test)
    queue._simulateCoalescingInTest = true

    var wasCalled = false
    queue.onSyncRequested = {
      wasCalled = true
    }

    queue.requestSync()

    // Wait for callback
    try? await Task.sleep(nanoseconds: 50_000_000)

    XCTAssertTrue(wasCalled, "onSyncRequested should have been called")

    // Cleanup
    queue.cancelLoop()
    await queue.awaitLoop()
    #endif
  }

  // MARK: - Coalescing Behavior Tests

  #if DEBUG
  func test_multipleRequests_coalesced() async throws {
    let queue = SyncQueue(mode: .test)
    queue._simulateCoalescingInTest = true

    var syncCount = 0
    queue.onSyncRequested = {
      syncCount += 1
      // Small delay to allow coalescing
      try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    // Fire multiple requests rapidly
    for _ in 0 ..< 10 {
      queue.requestSync()
    }

    // Wait for processing
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms

    // Should have coalesced multiple requests
    // Exact count depends on timing, but should be much less than 10
    XCTAssertGreaterThan(syncCount, 0, "Should process at least once")
    XCTAssertLessThan(syncCount, 10, "Should coalesce multiple requests")

    // Cleanup
    queue.cancelLoop()
    await queue.awaitLoop()
  }
  #endif
}
