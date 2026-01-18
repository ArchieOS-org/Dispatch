//
//  BatchSyncResult.swift
//  Dispatch
//
//  Result type for batch sync operations that surfaces individual failures.
//  Used by sync handlers to report which entities succeeded vs failed.
//

import Foundation

// MARK: - BatchSyncResult

/// Result of a batch sync operation that surfaces individual failures.
/// Use this to understand which entities succeeded and which failed during batch sync.
///
/// Example usage:
/// ```swift
/// let result = await syncHandler.syncUpWithResult(context: context)
/// if result.hasFailures {
///   for (entity, error) in result.failed {
///     debugLog.error("Failed to sync \(entity.id): \(error.userFacingMessage)")
///   }
/// }
/// ```
struct BatchSyncResult<Entity> {

  // MARK: Lifecycle

  // MARK: - Initializers

  /// Creates a batch sync result.
  /// - Parameters:
  ///   - succeeded: Entities that successfully synced
  ///   - failed: Entities that failed with their errors
  init(succeeded: [Entity] = [], failed: [(entity: Entity, error: SyncError)] = []) {
    self.succeeded = succeeded
    self.failed = failed
  }

  // MARK: Internal

  /// Creates an empty result (no entities attempted).
  static var empty: BatchSyncResult<Entity> {
    BatchSyncResult(succeeded: [], failed: [])
  }

  // MARK: - Properties

  /// Entities that were successfully synced
  let succeeded: [Entity]

  /// Entities that failed to sync with their corresponding errors
  let failed: [(entity: Entity, error: SyncError)]

  // MARK: - Computed Properties

  /// Whether any entities failed to sync
  var hasFailures: Bool {
    !failed.isEmpty
  }

  /// Number of entities that failed to sync
  var failureCount: Int {
    failed.count
  }

  /// Number of entities that successfully synced
  var successCount: Int {
    succeeded.count
  }

  /// Total number of entities attempted (succeeded + failed)
  var totalCount: Int {
    succeeded.count + failed.count
  }

  /// Whether all entities synced successfully
  var isComplete: Bool {
    failed.isEmpty
  }

  /// All errors from failed sync attempts
  var errors: [SyncError] {
    failed.map { $0.error }
  }

  /// Whether any failures are potentially recoverable by retrying
  var hasRetryableFailures: Bool {
    failed.contains { $0.error.isRetryable }
  }

  /// Failures that are potentially recoverable by retrying
  var retryableFailures: [(entity: Entity, error: SyncError)] {
    failed.filter { $0.error.isRetryable }
  }

  /// Failures that are fatal and won't recover by retrying
  var fatalFailures: [(entity: Entity, error: SyncError)] {
    failed.filter { !$0.error.isRetryable }
  }

  // MARK: - Aggregate Summary

  /// Returns a human-readable summary of the batch result.
  /// Useful for logging and debugging.
  var summary: String {
    if failed.isEmpty {
      "All \(succeeded.count) entities synced successfully."
    } else if succeeded.isEmpty {
      "All \(failed.count) entities failed to sync."
    } else {
      "\(succeeded.count) synced, \(failed.count) failed."
    }
  }

  /// Returns a detailed error summary for logging.
  /// Groups errors by type for clearer reporting.
  var errorSummary: String {
    guard hasFailures else { return "No errors." }

    var errorCounts: [String: Int] = [:]
    for (_, error) in failed {
      let key = error.userFacingMessage
      errorCounts[key, default: 0] += 1
    }

    let lines = errorCounts.map { message, count -> String in
      if count == 1 {
        return "- \(message)"
      }
      return "- \(message) (\(count)x)"
    }

    return lines.joined(separator: "\n")
  }

  /// Creates a fully successful result with no failures.
  /// - Parameter entities: All entities that succeeded
  static func success(_ entities: [Entity]) -> BatchSyncResult<Entity> {
    BatchSyncResult(succeeded: entities, failed: [])
  }

  /// Creates a result from a single failed entity.
  /// - Parameters:
  ///   - entity: The entity that failed
  ///   - error: The error that occurred
  static func singleFailure(_ entity: Entity, error: SyncError) -> BatchSyncResult<Entity> {
    BatchSyncResult(succeeded: [], failed: [(entity, error)])
  }

}

// MARK: BatchSyncResult.Builder

extension BatchSyncResult {

  /// A mutable builder for accumulating batch sync results.
  /// Use this when processing entities one at a time.
  ///
  /// Example:
  /// ```swift
  /// var builder = BatchSyncResult<TaskItem>.Builder()
  /// for task in tasks {
  ///   do {
  ///     try await syncTask(task)
  ///     builder.addSuccess(task)
  ///   } catch {
  ///     builder.addFailure(task, error: SyncError.from(error))
  ///   }
  /// }
  /// let result = builder.build()
  /// ```
  struct Builder {

    // MARK: Internal

    /// Adds a successfully synced entity.
    mutating func addSuccess(_ entity: Entity) {
      succeeded.append(entity)
    }

    /// Adds multiple successfully synced entities.
    mutating func addSuccesses(_ entities: [Entity]) {
      succeeded.append(contentsOf: entities)
    }

    /// Adds a failed entity with its error.
    mutating func addFailure(_ entity: Entity, error: SyncError) {
      failed.append((entity, error))
    }

    /// Builds the final immutable result.
    func build() -> BatchSyncResult<Entity> {
      BatchSyncResult(succeeded: succeeded, failed: failed)
    }

    // MARK: Private

    private var succeeded: [Entity] = []
    private var failed: [(entity: Entity, error: SyncError)] = []

  }
}
