//
//  RefinementRequest.swift
//  Dispatch
//
//  Refinement request model for prompt-based output improvement.
//  Tracks refinement history for user reference.
//

import Foundation

// MARK: - RefinementRequest

/// A user's request to refine the AI-generated output.
/// PHASE 3: Real AI refinement with prompt guidance.
struct RefinementRequest: Identifiable, Equatable {

  // MARK: - Properties

  /// Unique identifier for this request
  let id: UUID

  /// User's refinement instructions
  let prompt: String

  /// When this refinement was requested
  let timestamp: Date

  // MARK: - Initialization

  init(
    id: UUID = UUID(),
    prompt: String,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.prompt = prompt
    self.timestamp = timestamp
  }

  // MARK: - Equatable

  static func == (lhs: RefinementRequest, rhs: RefinementRequest) -> Bool {
    lhs.id == rhs.id &&
    lhs.prompt == rhs.prompt &&
    lhs.timestamp == rhs.timestamp
  }
}
