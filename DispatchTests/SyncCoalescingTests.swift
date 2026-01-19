//
//  SyncCoalescingTests.swift
//  DispatchTests
//
//  Verifies Jobs Standard Phase 2: Coalescing Sync Loop.
//  Ensures that bursts of requests result in minimal actual sync executions.
//

import OSLog
import XCTest
@testable import DispatchApp

@MainActor
final class SyncCoalescingTests: XCTestCase {

  // MARK: Internal

  func testBurstCoalescing() async throws {
    // 1. Setup isolated manager in logic-only mode
    let manager = SyncManager(mode: .test)

    #if DEBUG
    manager._simulateCoalescingInTest = true
    #else
    throw XCTSkip("Coalescing logic test requires DEBUG mode")
    #endif

    // 2. Trigger Burst
    // Fire 100 requests rapidly without yielding
    let burstCount = 100
    Self.logger.info("Firing \(burstCount) sync requests...")

    // Capture start runId
    // syncRunId is internal, reachable via @testable
    let startRunId = manager.syncRunId

    for _ in 0 ..< burstCount {
      manager.requestSync()
    }

    // 3. Wait for at least one sync to complete using condition waiting
    // instead of arbitrary sleep. This is deterministic because we wait for
    // actual state change rather than elapsed time.
    let conditionMet = await waitForCondition(timeout: 2.0) {
      manager.syncRunId > startRunId
    }

    XCTAssertTrue(conditionMet, "Sync should have run at least once")

    // 4. Assert
    let endRunId = manager.syncRunId
    let delta = endRunId - startRunId

    Self.logger.info("Syncs executed: \(delta) (from \(burstCount) requests)")

    // Verification:
    // - Must be > 0 (it ran)
    // - Must be << 100 (it coalesced)
    // Typically this is 1 (if loop caught all) or 2 (if one slipped in during the first execution)
    XCTAssertGreaterThan(delta, 0, "Should execute at least once")
    XCTAssertLessThan(delta, 10, "Should coalesce 100 requests into minimal executions (actual: \(delta))")

    // 5. Deterministic Teardown
    await manager.shutdown()
  }

  // MARK: Private

  private static let logger = Logger(subsystem: "Dispatch", category: "SyncCoalescingTests")

}
