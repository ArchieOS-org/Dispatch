//
//  ConflictResolver.swift
//  Dispatch
//
//  Extracted from SyncManager (PATCHSET 2) - handles in-flight tracking and
//  conflict resolution logic for sync operations.
//

import Foundation

// MARK: - ConflictResolver

/// Manages in-flight tracking and conflict resolution decisions for sync operations.
/// Extracted from SyncManager to isolate conflict logic from sync operations.
@MainActor
final class ConflictResolver {

  // MARK: - In-Flight Tracking

  /// Tasks currently being synced up - skip realtime echoes for these
  /// NOTE: Will be removed in Phase 3 once origin_user_id filtering is validated
  private(set) var inFlightTaskIds = Set<UUID>()

  /// Activities currently being synced up - skip realtime echoes for these
  /// NOTE: Will be removed in Phase 3 once origin_user_id filtering is validated
  private(set) var inFlightActivityIds = Set<UUID>()

  /// Notes currently being synced up - skip realtime echoes for these
  private(set) var inFlightNoteIds = Set<UUID>()

  /// Task assignees currently being synced up - skip realtime echoes for these
  private(set) var inFlightTaskAssigneeIds = Set<UUID>()

  /// Activity assignees currently being synced up - skip realtime echoes for these
  private(set) var inFlightActivityAssigneeIds = Set<UUID>()

  /// Listings currently being synced up - skip realtime echoes for these
  private(set) var inFlightListingIds = Set<UUID>()

  // MARK: - Mark In-Flight

  /// Mark task IDs as in-flight before sync up to prevent realtime echo overwrites
  func markTasksInFlight(_ ids: Set<UUID>) {
    inFlightTaskIds = ids
  }

  /// Mark activity IDs as in-flight before sync up to prevent realtime echo overwrites
  func markActivitiesInFlight(_ ids: Set<UUID>) {
    inFlightActivityIds = ids
  }

  /// Mark note IDs as in-flight before sync up to prevent realtime echo overwrites
  func markNotesInFlight(_ ids: Set<UUID>) {
    inFlightNoteIds = ids
  }

  /// Mark task assignee IDs as in-flight before sync up to prevent realtime echo overwrites
  func markTaskAssigneesInFlight(_ ids: Set<UUID>) {
    inFlightTaskAssigneeIds = ids
  }

  /// Mark activity assignee IDs as in-flight before sync up to prevent realtime echo overwrites
  func markActivityAssigneesInFlight(_ ids: Set<UUID>) {
    inFlightActivityAssigneeIds = ids
  }

  /// Mark listing IDs as in-flight before sync up to prevent realtime echo overwrites
  func markListingsInFlight(_ ids: Set<UUID>) {
    inFlightListingIds = ids
  }

  // MARK: - Clear In-Flight

  /// Clear all task in-flight IDs after sync completes
  func clearTasksInFlight() {
    inFlightTaskIds.removeAll()
  }

  /// Clear all activity in-flight IDs after sync completes
  func clearActivitiesInFlight() {
    inFlightActivityIds.removeAll()
  }

  /// Clear all note in-flight IDs after sync completes
  func clearNotesInFlight() {
    inFlightNoteIds.removeAll()
  }

  /// Clear all task assignee in-flight IDs after sync completes
  func clearTaskAssigneesInFlight() {
    inFlightTaskAssigneeIds.removeAll()
  }

  /// Clear all activity assignee in-flight IDs after sync completes
  func clearActivityAssigneesInFlight() {
    inFlightActivityAssigneeIds.removeAll()
  }

  /// Clear all listing in-flight IDs after sync completes
  func clearListingsInFlight() {
    inFlightListingIds.removeAll()
  }

  /// Clear all in-flight IDs (used during shutdown or error recovery)
  func clearAllInFlight() {
    inFlightTaskIds.removeAll()
    inFlightActivityIds.removeAll()
    inFlightNoteIds.removeAll()
    inFlightTaskAssigneeIds.removeAll()
    inFlightActivityAssigneeIds.removeAll()
    inFlightListingIds.removeAll()
  }

  // MARK: - In-Flight Checks

  /// Check if a task is currently in-flight (being synced up)
  func isTaskInFlight(_ id: UUID) -> Bool {
    inFlightTaskIds.contains(id)
  }

  /// Check if an activity is currently in-flight (being synced up)
  func isActivityInFlight(_ id: UUID) -> Bool {
    inFlightActivityIds.contains(id)
  }

  /// Check if a note is currently in-flight (being synced up)
  func isNoteInFlight(_ id: UUID) -> Bool {
    inFlightNoteIds.contains(id)
  }

  /// Check if a task assignee is currently in-flight (being synced up)
  func isTaskAssigneeInFlight(_ id: UUID) -> Bool {
    inFlightTaskAssigneeIds.contains(id)
  }

  /// Check if an activity assignee is currently in-flight (being synced up)
  func isActivityAssigneeInFlight(_ id: UUID) -> Bool {
    inFlightActivityAssigneeIds.contains(id)
  }

  /// Check if a listing is currently in-flight (being synced up)
  func isListingInFlight(_ id: UUID) -> Bool {
    inFlightListingIds.contains(id)
  }

  // MARK: - Conflict Resolution

  /// Determines if a model should be treated as "local-authoritative" during SyncDown.
  /// Local-authoritative items should NOT be overwritten by server state until SyncUp succeeds.
  ///
  /// Returns true if:
  /// - The model has pending local changes (syncState == .pending)
  /// - The model has a failed sync attempt (syncState == .failed)
  /// - The model is currently in-flight (being synced up right now)
  @inline(__always)
  func isLocalAuthoritative(_ model: some RealtimeSyncable, inFlight: Bool) -> Bool {
    model.syncState == .pending || model.syncState == .failed || inFlight
  }
}
