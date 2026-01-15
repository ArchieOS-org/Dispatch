//
//  SyncManagerIsolationTests.swift
//  DispatchTests
//
//  Created to verify Jobs Standard Phase 1: Deterministic Shutdown.
//

import SwiftData
import XCTest
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

    // 5. Verify quiescence (Exhaustive Checklist)
    // Ensure ALL named tasks are nil-ed out.
    #if DEBUG
    XCTAssertNil(manager.debugHangingTask, "debugHangingTask should be nil")
    #endif

    XCTAssertNil(manager.syncLoopTask, "syncLoopTask should be nil")
    XCTAssertNil(manager.statusTask, "statusTask should be nil")
    XCTAssertNil(manager.broadcastTask, "broadcastTask should be nil")
    XCTAssertNil(manager.startBroadcastListeningTask, "startBroadcastListeningTask should be nil")

    XCTAssertNil(manager.tasksSubscriptionTask, "tasksSubscriptionTask should be nil")
    XCTAssertNil(manager.activitiesSubscriptionTask, "activitiesSubscriptionTask should be nil")
    XCTAssertNil(manager.listingsSubscriptionTask, "listingsSubscriptionTask should be nil")
    XCTAssertNil(manager.usersSubscriptionTask, "usersSubscriptionTask should be nil")
    XCTAssertNil(manager.notesSubscriptionTask, "notesSubscriptionTask should be nil")

    XCTAssertNil(manager.realtimeChannel, "realtimeChannel should be nil")
    XCTAssertNil(manager.broadcastChannel, "broadcastChannel should be nil")
  }

  func testUserDefaultsIsolation() async {
    #if DEBUG
    // 1. Capture current defaults state
    let key = SyncManager.lastSyncTimeKey
    let originalValue = UserDefaults.standard.object(forKey: key)

    /// 2. Create TEST mode manager
    let manager = SyncManager(mode: .test)

    /// 3. Set lastSyncTime via debug hook
    let testDate = Date()
    manager._debugSetLastSyncTime(testDate)

    // 4. Assert: Manager state updated
    XCTAssertEqual(manager.lastSyncTime, testDate, "Manager state should update in memory")

    /// 5. Assert: Persistence UNCHANGED
    let currentValue = UserDefaults.standard.object(forKey: key)

    if let originalDate = originalValue as? Date, let currDate = currentValue as? Date {
      XCTAssertEqual(originalDate, currDate, "UserDefaults should not be modified in .test mode")
    } else {
      XCTAssertNil(currentValue, "UserDefaults should remain nil if originally nil")
    }
    #endif
  }
}
