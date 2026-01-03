//
//  SyncCoalescingTests.swift
//  DispatchTests
//
//  Verifies Jobs Standard Phase 2: Coalescing Sync Loop.
//  Ensures that bursts of requests result in minimal actual sync executions.
//

import XCTest
@testable import DispatchApp

@MainActor
final class SyncCoalescingTests: XCTestCase {
    
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
        print("Firing \(burstCount) sync requests...")
        
        // Capture start runId
        // syncRunId is internal, reachable via @testable
        let startRunId = manager.syncRunId
        
        for _ in 0..<burstCount {
            manager.requestSync()
        }
        
        // 3. Wait for Quiescence
        // The simulated sync takes 50ms.
        // We wait 300ms, which is plenty of time for 1-2 loops but NOT 100 loops (which would take 5s)
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // 4. Assert
        let endRunId = manager.syncRunId
        let delta = endRunId - startRunId
        
        print("Syncs executed: \(delta) (from \(burstCount) requests)")
        
        // Verification:
        // - Must be > 0 (it ran)
        // - Must be << 100 (it coalesced)
        // Typically this is 1 (if loop caught all) or 2 (if one slipped in during the first execution)
        XCTAssertGreaterThan(delta, 0, "Should execute at least once")
        XCTAssertLessThan(delta, 10, "Should coalesce 100 requests into minimal executions (actual: \(delta))")
        
        // 5. Deterministic Teardown
        await manager.shutdown()
    }
}
