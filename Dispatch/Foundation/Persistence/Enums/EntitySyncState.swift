//
//  EntitySyncState.swift
//  Dispatch
//
//  Per-entity sync state for tracking individual record sync status.
//  Error messages stored separately in lastSyncError to avoid SwiftData bloat.
//

import Foundation

/// Sync state for individual entities.
/// Error messages stored separately to avoid SwiftData change-set bloat when messages change.
enum EntitySyncState: String, Codable, Equatable {
    /// Entity is synchronized with server
    case synced

    /// Entity has local changes pending sync
    case pending

    /// Entity sync failed - check lastSyncError for details
    case failed
}
