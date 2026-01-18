//
//  SyncError+UserFacing.swift
//  Dispatch
//
//  Shared error-to-message conversion for sync errors.
//  Used by SyncManager and tests to produce consistent user-facing messages.
//

import Foundation

/// Convert sync errors to user-friendly messages.
/// Internal visibility allows access from both main target and tests.
///
/// - Parameter error: The error to convert.
/// - Returns: A user-friendly error message string.
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

  // Detect Postgres/RLS errors with table-aware messaging
  // Note: PostgrestError handling ideally involves checking the error code (e.g. 42501 or PGRST102)
  let errorString = String(describing: error).lowercased()
  if errorString.contains("42501") || errorString.contains("permission denied") {
    // Provide table-specific error messages for better debugging
    if errorString.contains("notes") {
      return "Permission denied syncing notes."
    }
    if errorString.contains("listings") {
      return "Permission denied syncing listings."
    }
    if errorString.contains("tasks") {
      return "Permission denied syncing tasks."
    }
    if errorString.contains("activities") {
      return "Permission denied syncing activities."
    }
    if errorString.contains("users") {
      return "Permission denied syncing user profile."
    }
    if errorString.contains("properties") {
      return "Permission denied syncing properties."
    }
    return "Permission denied during sync."
  }

  return "Sync failed: \(error.localizedDescription)"
}
