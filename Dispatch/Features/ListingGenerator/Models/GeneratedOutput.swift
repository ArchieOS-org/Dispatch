//
//  GeneratedOutput.swift
//  Dispatch
//
//  A/B output model for comparing AI-generated descriptions.
//  Supports dual output comparison and preference selection.
//

import Foundation

// MARK: - OutputVersion

/// Version identifier for A/B comparison.
enum OutputVersion: String, CaseIterable, Identifiable {
  case a = "Version A"
  case b = "Version B"

  // MARK: Internal

  var id: String { rawValue }

  /// Short label for compact display
  var shortLabel: String {
    switch self {
    case .a: "A"
    case .b: "B"
    }
  }

  /// Description of the version's tone
  var toneDescription: String {
    switch self {
    case .a: "Professional & Formal"
    case .b: "Warm & Inviting"
    }
  }
}

// MARK: - GeneratedOutput

/// A single AI-generated output for comparison.
/// Contains all MLS fields and metadata about the generation.
struct GeneratedOutput: Identifiable, Equatable {

  // MARK: Lifecycle

  // MARK: - Initialization

  init(
    id: UUID = UUID(),
    version: OutputVersion,
    mlsFields: MLSFields,
    generatedAt: Date = Date(),
    isSelected: Bool = false
  ) {
    self.id = id
    self.version = version
    self.mlsFields = mlsFields
    self.generatedAt = generatedAt
    self.isSelected = isSelected
  }

  // MARK: Internal

  // MARK: - Properties

  /// Unique identifier for this output
  let id: UUID

  /// Which version this output represents (A or B)
  let version: OutputVersion

  /// All generated MLS fields
  var mlsFields: MLSFields

  /// When this output was generated
  let generatedAt: Date

  /// Whether this version is currently selected by the user
  var isSelected: Bool

  // MARK: - Equatable

  static func ==(lhs: GeneratedOutput, rhs: GeneratedOutput) -> Bool {
    lhs.id == rhs.id &&
      lhs.version == rhs.version &&
      lhs.mlsFields == rhs.mlsFields &&
      lhs.generatedAt == rhs.generatedAt &&
      lhs.isSelected == rhs.isSelected
  }
}

// MARK: - PreferenceLog

/// Training data log for A/B preference selection.
/// PHASE 3: Submit to backend for model training.
struct PreferenceLog: Identifiable, Equatable {

  // MARK: Lifecycle

  // MARK: - Initialization

  init(
    id: UUID = UUID(),
    sessionId: UUID,
    inputHash: String,
    selectedVersion: OutputVersion,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.sessionId = sessionId
    self.inputHash = inputHash
    self.selectedVersion = selectedVersion
    self.timestamp = timestamp
  }

  // MARK: Internal

  // MARK: - Properties

  /// Unique identifier for this preference log
  let id: UUID

  /// Session ID grouping related preferences
  let sessionId: UUID

  /// Hash of input data for correlation
  let inputHash: String

  /// Which version the user selected
  let selectedVersion: OutputVersion

  /// When the selection was made
  let timestamp: Date

}
