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

  /// Helper to convert sync errors to user-friendly messages
  func userFacingMessage(for error: Error) -> String {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost:
        return "No internet connection."
      case .timedOut:
        return "Connection timed out."
      default:
        return "Network error."
      }
    }

    let errorString = String(describing: error).lowercased()
    if errorString.contains("42501") || errorString.contains("permission denied") {
      return "Permission denied during sync."
    }

    return "Sync failed: \(error.localizedDescription)"
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
