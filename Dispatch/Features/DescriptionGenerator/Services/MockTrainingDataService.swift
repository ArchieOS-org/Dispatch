//
//  MockTrainingDataService.swift
//  Dispatch
//
//  Mock training data service for logging A/B preferences.
//  PHASE 3: Replace with real backend submission to training pipeline.
//

import Foundation

// MARK: - MockTrainingDataService

/// Mock service for logging A/B preference selections.
/// Preferences are logged locally for now; Phase 3 will submit to backend.
/// PHASE 3: Replace with real training pipeline submission
final class MockTrainingDataService: Sendable {

  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  /// Log a preference selection for training data.
  /// PHASE 3: Submit to training pipeline backend
  func logPreference(
    sessionId: UUID,
    selectedVersion: OutputVersion,
    inputHash: String
  ) {
    // PHASE 3: Submit to backend training pipeline
    // For now, just log to console for debugging
    // swiftlint:disable:next no_direct_standard_out_logs
    print("[Training] Preference logged: session=\(sessionId.uuidString.prefix(8)), version=\(selectedVersion.rawValue), input=\(inputHash.prefix(8))")
  }

  /// Log a refinement action for training data.
  /// PHASE 3: Submit refinement prompts to training pipeline
  func logRefinement(
    sessionId: UUID,
    selectedVersion: OutputVersion,
    prompt: String
  ) {
    // PHASE 3: Submit to backend training pipeline
    // swiftlint:disable:next no_direct_standard_out_logs
    print("[Training] Refinement logged: session=\(sessionId.uuidString.prefix(8)), version=\(selectedVersion.rawValue), prompt=\"\(prompt)\"")
  }

  /// Log a field edit for training data.
  /// PHASE 3: Track which fields users manually edit
  func logFieldEdit(
    sessionId: UUID,
    fieldName: String,
    originalValue: String,
    editedValue: String
  ) {
    // PHASE 3: Submit to backend training pipeline
    // swiftlint:disable:next no_direct_standard_out_logs
    print("[Training] Field edit logged: session=\(sessionId.uuidString.prefix(8)), field=\(fieldName)")
  }
}
