//
//  DebugSyncTelemetry.swift
//  Dispatch
//
//  Created for debugging SyncManager task leaks.
//

import Foundation

#if DEBUG
/// Thread-safe actor for tracking active task execution counts per object instance.
/// Used to verify that SyncManager cleans up all its background work on shutdown.
final actor DebugSyncTelemetry {
    static let shared = DebugSyncTelemetry()
    
    /// Map of ObjectIdentifier -> Active Task Count
    private var activeTaskCounts: [ObjectIdentifier: Int] = [:]
    
    /// Records that a task has started execution for the given object.
    func taskStarted(for oid: ObjectIdentifier) {
        activeTaskCounts[oid, default: 0] += 1
    }
    
    /// Records that a task has ended execution (finished or cancelled) for the given object.
    func taskEnded(for oid: ObjectIdentifier) {
        let current = activeTaskCounts[oid, default: 0]
        if current > 0 {
            activeTaskCounts[oid] = current - 1
        }
    }
    
    /// Returns the current active execution count for the object.
    func getCount(for oid: ObjectIdentifier) -> Int {
        return activeTaskCounts[oid, default: 0]
    }
    
    /// Returns true if the object has zero active tasks.
    func assertClean(for oid: ObjectIdentifier) -> Bool {
        return activeTaskCounts[oid, default: 0] == 0
    }
}
#endif
