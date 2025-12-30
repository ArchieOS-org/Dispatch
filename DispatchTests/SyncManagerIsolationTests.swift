//
//  SyncManagerIsolationTests.swift
//  DispatchTests
//
//  Created to verify Jobs Standard Phase 1: Deterministic Shutdown.
//

import XCTest
import SwiftData
@testable import DispatchApp

@MainActor
final class SyncManagerIsolationTests: XCTestCase {

    func testDeterministicShutdown() async throws {
        // 1. Setup - Use .test mode for zero side effects
        let manager = SyncManager(mode: .test)
        
        let oid = ObjectIdentifier(manager)
        
        // Initial state check
        let initialCount = await DebugSyncTelemetry.shared.getCount(for: oid)
        XCTAssertEqual(initialCount, 0, "Should start with 0 tasks")
        
        // 2. Spawn a debug task (duration 5s, so it won't finish naturally anytime soon)
        manager.performDebugTask(duration: 5.0)
        
        // 3. Verify task is running via Telemetry
        // Poll for task start (it's async, might take a hop)
        var activeCount = 0
        for _ in 0..<20 { // Poll for up to 2 seconds
            activeCount = await DebugSyncTelemetry.shared.getCount(for: oid)
            if activeCount > 0 { break }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        XCTAssertEqual(activeCount, 1, "Should have 1 active task running")
        
        // 4. Shutdown
        // This MUST cancel the task and await its completion.
        await manager.shutdown()
        
        // 5. Verify quiescence
        let finalCount = await DebugSyncTelemetry.shared.getCount(for: oid)
        XCTAssertEqual(finalCount, 0, "Should have 0 active tasks after shutdown")
    }
}
