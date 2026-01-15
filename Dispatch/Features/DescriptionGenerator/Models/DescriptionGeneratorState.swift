//
//  DescriptionGeneratorState.swift
//  Dispatch
//
//  Observable state for the AI Listing Description Generator.
//  Manages input mode, generation status, and output handling.
//

import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - InputMode

/// Determines how property information is provided for description generation.
enum DescriptionInputMode: String, CaseIterable, Identifiable {
  /// Select from existing listings in the system
  case existingListing
  /// Manually enter property details
  case manualEntry

  // MARK: Internal

  var id: String { rawValue }

  var title: String {
    switch self {
    case .existingListing: "Existing Listing"
    case .manualEntry: "Manual Entry"
    }
  }

  var icon: String {
    switch self {
    case .existingListing: "house"
    case .manualEntry: "pencil.line"
    }
  }
}

// MARK: - DescriptionGeneratorState

/// Central state for the Description Generator feature.
/// Manages the two-screen flow: Input -> Output
@Observable
@MainActor
final class DescriptionGeneratorState {

  // MARK: Lifecycle

  init(
    preselectedListing: Listing? = nil,
    aiService: AIServiceProtocol = MockAIService()
  ) {
    self.selectedListing = preselectedListing
    self.aiService = aiService

    // If a listing is preselected, start in existing listing mode
    if preselectedListing != nil {
      inputMode = .existingListing
    }
  }

  // MARK: Internal

  // MARK: - Input State

  /// Current input mode
  var inputMode: DescriptionInputMode = .existingListing

  /// Selected listing (when using existing listing mode)
  var selectedListing: Listing?

  /// Manual property address
  var manualAddress: String = ""

  /// Manual property type description
  var manualPropertyType: String = ""

  /// Manual property details (free-form text)
  var manualDetails: String = ""

  // MARK: - Output State

  /// The generated description text
  var generatedDescription: String = ""

  /// Current status of the description
  var status: DescriptionStatus = .draft

  /// Whether generation is in progress
  var isLoading: Bool = false

  /// Error message if generation failed
  var errorMessage: String?

  /// Whether we're showing the output screen
  var showingOutput: Bool = false

  // MARK: - Computed Properties

  /// Whether the generate button should be enabled
  var canGenerate: Bool {
    switch inputMode {
    case .existingListing:
      return selectedListing != nil && !isLoading
    case .manualEntry:
      return !manualAddress.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }
  }

  /// Property information summary for display
  var propertyTitle: String {
    switch inputMode {
    case .existingListing:
      return selectedListing?.address ?? "No listing selected"
    case .manualEntry:
      return manualAddress.isEmpty ? "No address entered" : manualAddress
    }
  }

  // MARK: - Actions

  /// Generate a description based on current input
  func generateDescription() async {
    guard canGenerate else { return }

    isLoading = true
    errorMessage = nil

    do {
      let input = buildPromptInput()
      generatedDescription = try await aiService.generateDescription(for: input)
      status = .draft
      showingOutput = true
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  /// Send the description to the agent for approval
  func sendToAgent() {
    guard !generatedDescription.isEmpty else { return }

    // PHASE 2: Real agent approval workflow
    status = .sent

    // PHASE 2: Mock auto-transition to ready after delay
    // In production, this would be triggered by agent action
    Task {
      try? await Task.sleep(for: .seconds(2))
      await MainActor.run {
        if status == .sent {
          status = .ready
        }
      }
    }
  }

  /// Mark the description as posted to MLS
  func markAsPosted() {
    guard status == .ready else { return }
    // PHASE 2: Persist to Supabase here
    status = .posted
  }

  /// Copy the generated description to the system clipboard
  func copyToClipboard() {
    guard !generatedDescription.isEmpty else { return }

    #if canImport(UIKit)
    UIPasteboard.general.string = generatedDescription
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(generatedDescription, forType: .string)
    #endif
  }

  /// Reset state for a new generation
  func reset() {
    generatedDescription = ""
    status = .draft
    errorMessage = nil
    showingOutput = false
  }

  // MARK: Private

  private let aiService: AIServiceProtocol

  /// Build the prompt input string from current state
  private func buildPromptInput() -> String {
    switch inputMode {
    case .existingListing:
      guard let listing = selectedListing else { return "" }
      var components: [String] = []
      components.append("Address: \(listing.address)")
      if !listing.city.isEmpty {
        components.append("City: \(listing.city)")
      }
      if let price = listing.price {
        components.append("Price: $\(price)")
      }
      components.append("Type: \(listing.listingType.displayName)")
      return components.joined(separator: "\n")

    case .manualEntry:
      var components: [String] = []
      components.append("Address: \(manualAddress)")
      if !manualPropertyType.isEmpty {
        components.append("Property Type: \(manualPropertyType)")
      }
      if !manualDetails.isEmpty {
        components.append("Details: \(manualDetails)")
      }
      return components.joined(separator: "\n")
    }
  }
}

// MARK: - ListingType Extension

extension ListingType {
  var displayName: String {
    switch self {
    case .sale: "Sale"
    case .lease: "Lease"
    case .preListing: "Pre-Listing"
    case .rental: "Rental"
    case .other: "Other"
    }
  }
}
