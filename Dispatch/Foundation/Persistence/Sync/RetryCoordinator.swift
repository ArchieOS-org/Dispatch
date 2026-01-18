//
//  RetryCoordinator.swift
//  Dispatch
//
//  Extracted from SyncManager.swift for cohesion.
//  Manages exponential backoff retry logic for failed sync entities.
//

import Foundation
import SwiftData

// MARK: - RetryPolicy

/// Defines exponential backoff policy for failed sync retries.
/// Delays: 1s, 2s, 4s, 8s, 16s, capped at 30s.
enum RetryPolicy {
  static let maxRetries = 5
  static let maxDelay: TimeInterval = 30

  /// Calculate delay for a given retry attempt (0-indexed).
  /// Attempt 0 = 1s, Attempt 1 = 2s, Attempt 2 = 4s, etc.
  static func delay(for attempt: Int) -> TimeInterval {
    let baseDelay = pow(2.0, Double(attempt))
    return min(maxDelay, baseDelay)
  }
}

// MARK: - RetryableEntity

/// Protocol for entities that support retry with exponential backoff.
protocol RetryableEntity: PersistentModel {
  var id: UUID { get }
  var retryCount: Int { get set }
  var syncState: EntitySyncState { get set }
  var lastSyncError: String? { get set }
}

// MARK: - TaskItem + RetryableEntity

extension TaskItem: RetryableEntity { }

// MARK: - Activity + RetryableEntity

extension Activity: RetryableEntity { }

// MARK: - Listing + RetryableEntity

extension Listing: RetryableEntity { }

// MARK: - RetryCoordinator

/// Coordinates retry logic with exponential backoff for failed sync entities.
/// Extracted from SyncManager to improve cohesion and testability.
@MainActor
final class RetryCoordinator {

  // MARK: Lifecycle

  init(mode: SyncRunMode) {
    self.mode = mode
  }

  // MARK: Internal

  /// Retry syncing a specific entity with exponential backoff.
  /// - Parameters:
  ///   - entity: The entity to retry (TaskItem, Activity, or Listing)
  ///   - entityType: A string describing the entity type for logging
  ///   - performSync: Closure that performs the actual sync operation
  /// - Returns: true if retry was attempted, false if max retries exceeded
  @discardableResult
  func retryEntity(
    _ entity: some RetryableEntity,
    entityType: String,
    performSync: () async -> Void
  ) async -> Bool {
    let entityId = entity.id

    // Check if max retries exceeded (using persisted retryCount)
    if entity.retryCount >= RetryPolicy.maxRetries {
      debugLog.log(
        "retry\(entityType)() for \(entityId): max retries exceeded (\(entity.retryCount)), leaving in .failed state",
        category: .sync
      )
      return false
    }

    // Increment retry count (persisted on entity) and calculate delay
    entity.retryCount += 1
    let delay = RetryPolicy.delay(for: entity.retryCount - 1) // 0-indexed for delay calculation

    debugLog.log(
      "retry\(entityType)() for \(entityId): attempt \(entity.retryCount)/\(RetryPolicy.maxRetries), delay: \(delay)s",
      category: .sync
    )

    // Apply backoff delay (skip in test mode for fast, deterministic tests)
    if mode != .test {
      do {
        try await Task.sleep(for: .seconds(delay))
      } catch {
        debugLog.log("retry\(entityType)() cancelled during backoff delay", category: .sync)
        return false
      }
    }

    // Reset state and sync
    entity.syncState = .pending
    entity.lastSyncError = nil
    await performSync()
    return true
  }

  /// Retry syncing a specific TaskItem with exponential backoff.
  /// - Returns: true if retry was attempted, false if max retries exceeded.
  @discardableResult
  func retryTask(_ task: TaskItem, performSync: () async -> Void) async -> Bool {
    await retryEntity(task, entityType: "Task", performSync: performSync)
  }

  /// Retry syncing a specific Activity with exponential backoff.
  /// - Returns: true if retry was attempted, false if max retries exceeded.
  @discardableResult
  func retryActivity(_ activity: Activity, performSync: () async -> Void) async -> Bool {
    await retryEntity(activity, entityType: "Activity", performSync: performSync)
  }

  /// Retry syncing a specific Listing with exponential backoff.
  /// - Returns: true if retry was attempted, false if max retries exceeded.
  @discardableResult
  func retryListing(_ listing: Listing, performSync: () async -> Void) async -> Bool {
    await retryEntity(listing, entityType: "Listing", performSync: performSync)
  }

  /// Retry all failed entities with exponential backoff.
  /// Called on network restoration and app foreground.
  /// Respects max retries per entity - entities that exceed limit remain in .failed state.
  func retryFailedEntities(container: ModelContainer, performSync: () async -> Void) async {
    let context = container.mainContext

    // Fetch all entities and filter for failed ones (SwiftData predicate limitations)
    var failedTasks: [TaskItem] = []
    var failedActivities: [Activity] = []
    var failedListings: [Listing] = []

    do {
      let taskDescriptor = FetchDescriptor<TaskItem>()
      let allTasks = try context.fetch(taskDescriptor)
      failedTasks = allTasks.filter { $0.syncState == .failed }

      let activityDescriptor = FetchDescriptor<Activity>()
      let allActivities = try context.fetch(activityDescriptor)
      failedActivities = allActivities.filter { $0.syncState == .failed }

      let listingDescriptor = FetchDescriptor<Listing>()
      let allListings = try context.fetch(listingDescriptor)
      failedListings = allListings.filter { $0.syncState == .failed }
    } catch {
      debugLog.error("retryFailedEntities(): Failed to fetch entities", error: error)
      return
    }

    let totalFailed = failedTasks.count + failedActivities.count + failedListings.count
    if totalFailed == 0 {
      debugLog.log("retryFailedEntities(): No failed entities to retry", category: .sync)
      return
    }

    debugLog.log(
      "retryFailedEntities(): Found \(totalFailed) failed entities (\(failedTasks.count) tasks, \(failedActivities.count) activities, \(failedListings.count) listings)",
      category: .sync
    )

    // Filter to only entities that haven't exceeded max retries (using persisted retryCount)
    let retriableTasks = failedTasks.filter { $0.retryCount < RetryPolicy.maxRetries }
    let retriableActivities = failedActivities.filter { $0.retryCount < RetryPolicy.maxRetries }
    let retriableListings = failedListings.filter { $0.retryCount < RetryPolicy.maxRetries }

    let totalRetriable = retriableTasks.count + retriableActivities.count + retriableListings.count
    if totalRetriable == 0 {
      debugLog.log("retryFailedEntities(): All failed entities have exceeded max retries", category: .sync)
      return
    }

    debugLog.log("retryFailedEntities(): \(totalRetriable) entities eligible for retry", category: .sync)

    // Mark all retriable entities as pending (increment persisted retryCount and reset state)
    for task in retriableTasks {
      task.retryCount += 1
      task.syncState = .pending
      task.lastSyncError = nil
    }
    for activity in retriableActivities {
      activity.retryCount += 1
      activity.syncState = .pending
      activity.lastSyncError = nil
    }
    for listing in retriableListings {
      listing.retryCount += 1
      listing.syncState = .pending
      listing.lastSyncError = nil
    }

    // Trigger a sync to process the pending entities
    // Note: We don't apply individual backoff delays here because this is a batch retry
    // triggered by network restoration or app foreground. The sync itself will process
    // all pending entities together.
    await performSync()
  }

  // MARK: Private

  private let mode: SyncRunMode
}
