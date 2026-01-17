//
//  ListingGeneratorDraft.swift
//  Dispatch
//
//  SwiftData model for persisting Listing Generator drafts.
//  Stores snapshots of input and output state for resumable sessions.
//

import Foundation
import SwiftData

// MARK: - ListingGeneratorDraft

/// A persisted draft of a Listing Generator session.
/// Allows users to resume generation sessions and access previous outputs.
@Model
final class ListingGeneratorDraft {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    name: String,
    inputStateData: Data,
    outputStateData: Data? = nil,
    hasOutput: Bool = false,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.inputStateData = inputStateData
    self.outputStateData = outputStateData
    self.hasOutput = hasOutput
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  // MARK: Internal

  /// Unique identifier for this draft
  @Attribute(.unique) var id: UUID

  /// Display name (property address or "Untitled Draft")
  var name: String

  /// Encoded snapshot of input state (photos, documents, property selection, report settings)
  var inputStateData: Data

  /// Encoded snapshot of output state (generated outputs, MLS fields, selected version)
  /// Nil if generation has not been completed
  var outputStateData: Data?

  /// Quick check for whether output exists without decoding
  var hasOutput: Bool

  /// When this draft was first created
  var createdAt: Date

  /// When this draft was last modified
  var updatedAt: Date

  // MARK: - Convenience Methods

  /// Updates the draft with new data and timestamps
  func update(inputStateData: Data, outputStateData: Data?, hasOutput: Bool) {
    self.inputStateData = inputStateData
    self.outputStateData = outputStateData
    self.hasOutput = hasOutput
    updatedAt = Date()
  }

  /// Updates just the name
  func updateName(_ newName: String) {
    name = newName
    updatedAt = Date()
  }
}
