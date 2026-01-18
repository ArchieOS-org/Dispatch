//
//  EntitySyncHandlerProtocol.swift
//  Dispatch
//
//  Defines the contract for entity-specific sync handlers.
//  Each handler manages syncDown, syncUp, and upsert operations for a specific entity type.
//

import Foundation
import SwiftData

// MARK: - SyncHandlerDependencies

/// Shared dependencies injected into all entity sync handlers.
/// Provides access to mode, conflict resolver, and user context callbacks.
/// Note: Not Sendable because it contains @MainActor-isolated types (ConflictResolver, User).
struct SyncHandlerDependencies {
  let mode: SyncRunMode
  let conflictResolver: ConflictResolver
  let getCurrentUserID: () -> UUID?
  let getCurrentUser: () -> User?
  let fetchCurrentUser: (UUID) -> Void
  let updateListingConfigReady: (Bool) -> Void

  /// Converts any error to a structured SyncError.
  /// Use this for error classification and retry decisions.
  /// - Parameter error: The error to convert
  /// - Returns: A classified SyncError
  func syncError(from error: Error) -> SyncError {
    SyncError.from(error)
  }

  /// Helper to convert sync errors to user-friendly messages.
  /// Delegates to SyncError enum for consistent messaging across the codebase.
  /// - Parameter error: The error to convert
  /// - Returns: A user-friendly error message string
  func userFacingMessage(for error: Error) -> String {
    SyncError.from(error).userFacingMessage
  }
}

// MARK: - EntitySyncHandlerProtocol

/// Protocol defining the contract for entity-specific sync handlers.
/// Each entity handler implements sync operations for a specific model type.
@MainActor
protocol EntitySyncHandlerProtocol {
  /// Synchronize entities from remote (Supabase) to local (SwiftData)
  func syncDown(context: ModelContext, since: String) async throws

  /// Synchronize entities from local (SwiftData) to remote (Supabase)
  func syncUp(context: ModelContext) async throws
}
