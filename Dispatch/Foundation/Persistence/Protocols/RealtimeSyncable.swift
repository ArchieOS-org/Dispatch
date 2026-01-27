//
//  RealtimeSyncable.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import Foundation

// MARK: - RealtimeSyncable

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

  /// Check if sync operations should suppress markPending() calls.
  /// This prevents SwiftData dirty tracking from flipping synced entities back to pending
  /// during relationship mutations that occur as part of sync operations.
  ///
  /// **Why this is needed**: During sync, relationship mutations (e.g., appending assignees
  /// to a task's array) trigger SwiftData's dirty tracking, which can call markPending()
  /// and flip entities back to .pending even though they were just synced. This creates
  /// infinite sync loops where remote updates are perpetually skipped.
  @MainActor
  var shouldSuppressPending: Bool {
    SyncManager.shared.isSyncing
  }
}
