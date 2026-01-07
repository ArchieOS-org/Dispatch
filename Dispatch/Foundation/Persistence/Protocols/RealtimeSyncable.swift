//
//  RealtimeSyncable.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

/// Protocol for models that sync with Supabase.
/// ConflictStrategy is defined in Enums/ConflictStrategy.swift
protocol RealtimeSyncable {
    var syncedAt: Date? { get set }
    var syncState: EntitySyncState { get set }
    var lastSyncError: String? { get set }
    var conflictResolution: ConflictStrategy { get }
}

extension RealtimeSyncable {
    /// Default conflict resolution strategy
    var conflictResolution: ConflictStrategy {
        .lastWriteWins
    }

    /// Legacy computed property for backwards compatibility
    var isDirty: Bool {
        syncState == .pending
    }

    /// Convenience check for failed sync state
    var isSyncFailed: Bool {
        syncState == .failed
    }
}
