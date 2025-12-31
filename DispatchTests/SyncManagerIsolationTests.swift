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
        
        // 2. Spawn a debug task (duration 5s, so it won't finish naturally anytime soon)
        manager.performDebugTask(duration: 5.0)
        
        // 3. Verify task is registered
        // In DEBUG, we can access the internal property
        #if DEBUG
        // Allow a tiny yield to let the Task spin up assignment
        await Task.yield()
        XCTAssertNotNil(manager.debugHangingTask, "Debug task should be assigned")
        #endif
        
        // 4. Shutdown
        // This MUST cancel the task and await its completion.
        await manager.shutdown()
        
        // 5. Verify quiescence
        #if DEBUG
        XCTAssertNil(manager.debugHangingTask, "Debug task should be nil after shutdown")
        #endif
        
        // Ensure no leakage (though memory graph debugging is hard in XCTest, this logical check is good)
    }
}
