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
  /// Cooldown period for auto-recovery of permanently failed entities (1 hour)
  static let autoRecoveryCooldown: TimeInterval = 3600

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

// MARK: - RecoverableEntity

/// Protocol for entities that support auto-recovery with cooldown tracking.
/// Extends RetryableEntity with the ability to track when the entity was last
/// auto-recovered to prevent rapid re-reset loops.
protocol RecoverableEntity: RetryableEntity {
  var lastResetAttempt: Date? { get set }

  /// Mark as pending when modified (resets syncState and lastSyncError)
  func markPending()
}

// MARK: - TaskItem + RetryableEntity

extension TaskItem: RetryableEntity { }

// MARK: - TaskItem + RecoverableEntity

extension TaskItem: RecoverableEntity { }

// MARK: - Activity + RetryableEntity

extension Activity: RetryableEntity { }

// MARK: - Activity + RecoverableEntity

extension Activity: RecoverableEntity { }

// MARK: - Listing + RetryableEntity

extension Listing: RetryableEntity { }

// MARK: - Listing + RecoverableEntity

extension Listing: RecoverableEntity { }

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

    // Calculate delay from current retryCount (0-indexed) BEFORE incrementing
    let attempt = entity.retryCount
    let delay = RetryPolicy.delay(for: attempt)

    debugLog.log(
      "retry\(entityType)() for \(entityId): attempt \(attempt + 1)/\(RetryPolicy.maxRetries), delay: \(delay)s",
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

    // Increment retry count only after backoff completes successfully
    entity.retryCount += 1

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

  /// Auto-recover entities that have permanently failed (exceeded max retries).
  /// This resets entities so they can try syncing again, but only if enough time
  /// has passed since the last recovery attempt (cooldown period).
  ///
  /// This is distinct from `retryFailedEntities`:
  /// - `retryFailedEntities`: Handles entities still within retry limit (normal exponential backoff)
  /// - `autoRecoverFailedEntities`: Resurrects entities that are permanently stuck (exceeded max retries)
  ///
  /// - Parameters:
  ///   - container: The SwiftData model container
  ///   - cooldownPeriod: Minimum time since last recovery attempt (default: 1 hour)
  ///   - performSync: Closure to trigger sync after recovery
  /// - Returns: Number of entities that were recovered
  @discardableResult
  func autoRecoverFailedEntities(
    container: ModelContainer,
    cooldownPeriod: TimeInterval = RetryPolicy.autoRecoveryCooldown,
    performSync: () async -> Void
  ) async -> Int {
    let context = container.mainContext
    let now = Date()

    // Fetch all entities and filter for permanently failed ones (exceeded max retries)
    var permanentlyFailedTasks: [TaskItem] = []
    var permanentlyFailedActivities: [Activity] = []
    var permanentlyFailedListings: [Listing] = []

    do {
      let taskDescriptor = FetchDescriptor<TaskItem>()
      let allTasks = try context.fetch(taskDescriptor)
      permanentlyFailedTasks = allTasks.filter {
        $0.syncState == .failed && $0.retryCount >= RetryPolicy.maxRetries
      }

      let activityDescriptor = FetchDescriptor<Activity>()
      let allActivities = try context.fetch(activityDescriptor)
      permanentlyFailedActivities = allActivities.filter {
        $0.syncState == .failed && $0.retryCount >= RetryPolicy.maxRetries
      }

      let listingDescriptor = FetchDescriptor<Listing>()
      let allListings = try context.fetch(listingDescriptor)
      permanentlyFailedListings = allListings.filter {
        $0.syncState == .failed && $0.retryCount >= RetryPolicy.maxRetries
      }
    } catch {
      debugLog.error("autoRecoverFailedEntities(): Failed to fetch entities", error: error)
      return 0
    }

    let totalPermanentlyFailed = permanentlyFailedTasks.count +
      permanentlyFailedActivities.count +
      permanentlyFailedListings.count

    if totalPermanentlyFailed == 0 {
      debugLog.log("autoRecoverFailedEntities(): No permanently failed entities to recover", category: .sync)
      return 0
    }

    debugLog.log(
      "autoRecoverFailedEntities(): Found \(totalPermanentlyFailed) permanently failed entities (\(permanentlyFailedTasks.count) tasks, \(permanentlyFailedActivities.count) activities, \(permanentlyFailedListings.count) listings)",
      category: .sync
    )

    // Helper to check if entity is eligible for recovery (cooldown elapsed)
    func isEligibleForRecovery(_ lastResetAttempt: Date?) -> Bool {
      guard let lastAttempt = lastResetAttempt else {
        // Never been reset before, eligible for recovery
        return true
      }
      // Check if cooldown period has elapsed
      return now.timeIntervalSince(lastAttempt) > cooldownPeriod
    }

    var recoveredCount = 0

    // Recover eligible tasks
    for task in permanentlyFailedTasks where isEligibleForRecovery(task.lastResetAttempt) {
      task.lastResetAttempt = now
      task.retryCount = 0
      task.markPending()
      recoveredCount += 1
      debugLog.log("autoRecoverFailedEntities(): Recovered task \(task.id)", category: .sync)
    }

    // Recover eligible activities
    for activity in permanentlyFailedActivities where isEligibleForRecovery(activity.lastResetAttempt) {
      activity.lastResetAttempt = now
      activity.retryCount = 0
      activity.markPending()
      recoveredCount += 1
      debugLog.log("autoRecoverFailedEntities(): Recovered activity \(activity.id)", category: .sync)
    }

    // Recover eligible listings
    for listing in permanentlyFailedListings where isEligibleForRecovery(listing.lastResetAttempt) {
      listing.lastResetAttempt = now
      listing.retryCount = 0
      listing.markPending()
      recoveredCount += 1
      debugLog.log("autoRecoverFailedEntities(): Recovered listing \(listing.id)", category: .sync)
    }

    if recoveredCount == 0 {
      debugLog.log(
        "autoRecoverFailedEntities(): All permanently failed entities are still in cooldown period",
        category: .sync
      )
      return 0
    }

    debugLog.log(
      "autoRecoverFailedEntities(): Recovered \(recoveredCount) entities, triggering sync",
      category: .sync
    )

    // Trigger sync to process the recovered entities
    await performSync()
    return recoveredCount
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
