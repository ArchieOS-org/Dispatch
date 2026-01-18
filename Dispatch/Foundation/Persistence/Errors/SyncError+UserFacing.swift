//
//  SyncError+UserFacing.swift
//  Dispatch
//
//  Shared error-to-message conversion for sync errors.
//  Used by SyncManager and tests to produce consistent user-facing messages.
//
//  NOTE: This file now delegates to SyncError enum for consistent error handling.
//  The function is preserved for backward compatibility with existing callers.
//

import Foundation

/// Convert sync errors to user-friendly messages.
/// Internal visibility allows access from both main target and tests.
///
/// This function delegates to `SyncError.from(_:).userFacingMessage` for consistent
/// error handling across the codebase. The SyncError enum provides:
/// - Structured error classification
/// - Retry classification via `isRetryable`
/// - Consistent user-facing messages
///
/// - Parameter error: The error to convert.
/// - Returns: A user-friendly error message string.
func userFacingMessage(for error: Error) -> String {
  SyncError.from(error).userFacingMessage
}
