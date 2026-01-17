//
//  ListingGeneratorState.swift
//  Dispatch
//
//  Observable state for the AI Listing Generator.
//  Manages input mode, generation status, output handling,
//  photo/document uploads, A/B comparison, and refinement.
//

import Foundation
import Observation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - GeneratorNavigationPhase

/// Tracks the current screen in the two-screen listing generator flow.
enum GeneratorNavigationPhase: String, Hashable {
  /// Input screen: property selection, photo/document upload, report toggles
  case input
  /// Output screen: A/B comparison, refinement, MLS fields
  case output
}

// MARK: - ListingInputMode

/// Determines how property information is provided for listing generation.
enum ListingInputMode: String, CaseIterable, Identifiable {
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

// MARK: - ListingGeneratorState

/// Central state for the Listing Generator feature.
/// Manages the two-screen flow: Input -> Output
@Observable
@MainActor
final class ListingGeneratorState {

  // MARK: Lifecycle

  init(
    preselectedListing: Listing? = nil,
    aiService: AIServiceProtocol = MockAIService()
  ) {
    selectedListing = preselectedListing
    self.aiService = aiService

    // If a listing is preselected, start in existing listing mode
    if preselectedListing != nil {
      inputMode = .existingListing
    }
  }

  // MARK: Internal

  // MARK: - Input State

  /// Current input mode
  var inputMode: ListingInputMode = .existingListing

  /// Selected listing (when using existing listing mode)
  var selectedListing: Listing?

  /// Manual property address
  var manualAddress: String = ""

  /// Manual property type description
  var manualPropertyType: String = ""

  /// Manual property details (free-form text)
  var manualDetails: String = ""

  // MARK: - Navigation State

  /// Current screen in the two-screen flow (Input -> Output)
  var navigationPhase: GeneratorNavigationPhase = .input

  // MARK: - Output State

  /// The generated description text
  var generatedDescription: String = ""

  /// Current status of the listing
  var status: GeneratorStatus = .draft

  /// Whether generation is in progress
  var isLoading: Bool = false

  /// Error message if generation failed
  var errorMessage: String?

  /// Whether we're showing the output screen (kept for backward compatibility)
  var showingOutput: Bool = false

  // MARK: - Phase 2: Photo & Document State

  /// Uploaded photos for AI analysis
  /// PHASE 3: Persist to Supabase Storage
  var photos: [UploadedPhoto] = []

  /// Uploaded supporting documents
  /// PHASE 3: AI will extract text from documents
  var documents: [UploadedDocument] = []

  // MARK: - Phase 2: Dual Output A/B Comparison

  /// Generated output version A (professional tone)
  var outputA: GeneratedOutput?

  /// Generated output version B (warm tone)
  var outputB: GeneratedOutput?

  /// Currently selected output version
  var selectedVersion: OutputVersion?

  /// Session ID for this generation (used for training data correlation)
  var sessionId: UUID = .init()

  // MARK: - Phase 2: Refinement

  /// History of refinement requests
  var refinementHistory: [RefinementRequest] = []

  /// Current refinement prompt being entered
  var currentRefinementPrompt: String = ""

  /// Whether refinement is in progress
  var isRefining: Bool = false

  // MARK: - Report Integration

  /// Whether to fetch GEOWarehouse report during generation
  var enableGeoWarehouse: Bool = false

  /// Whether to fetch MPAC report during generation
  var enableMPAC: Bool = false

  /// Current phase of the generation process
  var generationPhase: GenerationPhase = .idle

  /// Reports that were fetched during generation
  var fetchedReports: [FetchedReport] = []

  /// Whether information was extracted from uploaded photos
  var extractedFromImages: Bool = false

  // MARK: - Draft Persistence

  /// ID of the current draft (if loaded from or saved to persistence)
  var currentDraftId: UUID?

  // MARK: - Task Management

  /// Task for the agent send workflow (auto-transition after delay)
  private var sendToAgentTask: Task<Void, Never>?

  /// Whether the generate button should be enabled
  var canGenerate: Bool {
    switch inputMode {
    case .existingListing:
      selectedListing != nil && !isLoading
    case .manualEntry:
      !manualAddress.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }
  }

  /// Property information summary for display
  var propertyTitle: String {
    switch inputMode {
    case .existingListing:
      selectedListing?.address ?? "No listing selected"
    case .manualEntry:
      manualAddress.isEmpty ? "No address entered" : manualAddress
    }
  }

  /// Get the currently selected output
  var selectedOutput: GeneratedOutput? {
    switch selectedVersion {
    case .a: outputA
    case .b: outputB
    case .none: nil
    }
  }

  /// Returns which report types are enabled
  var enabledReports: Set<ReportType> {
    var reports: Set<ReportType> = []
    if enableGeoWarehouse { reports.insert(.geoWarehouse) }
    if enableMPAC { reports.insert(.mpac) }
    return reports
  }

  // MARK: - Phase 2: MLS Field Management

  /// Get a binding to the selected output's MLS fields
  /// Returns nil if no output is selected
  var selectedMLSFields: MLSFields? {
    get { selectedOutput?.mlsFields }
    set {
      guard let newValue else { return }
      if selectedVersion == .a {
        outputA?.mlsFields = newValue
      } else if selectedVersion == .b {
        outputB?.mlsFields = newValue
      }
    }
  }

  /// Get the original MLS fields for reset functionality
  var originalMLSFields: MLSFields {
    // PHASE 3: Store original fields separately for proper reset
    // For now, return a default set
    switch selectedVersion {
    case .a:
      createMockMLSFields(tone: .a)
    case .b:
      createMockMLSFields(tone: .b)
    case .none:
      MLSFields()
    }
  }

  /// Create a new ListingGeneratorState instance from a draft.
  /// Useful for creating a fresh state object initialized from persistence.
  static func createFromDraft(
    _ draft: ListingGeneratorDraft,
    modelContext: ModelContext,
    aiService: AIServiceProtocol = MockAIService()
  ) throws -> ListingGeneratorState {
    let state = ListingGeneratorState(aiService: aiService)
    try state.loadDraft(draft, modelContext: modelContext)
    return state
  }

  /// Delete a draft from persistence
  static func deleteDraft(_ draft: ListingGeneratorDraft, from modelContext: ModelContext) throws {
    modelContext.delete(draft)
    try modelContext.save()
  }

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

    // PHASE 3: Real agent approval workflow
    status = .sent

    // Cancel any existing send task before starting a new one
    sendToAgentTask?.cancel()

    // PHASE 3: Mock auto-transition to ready after delay
    // In production, this would be triggered by agent action
    sendToAgentTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      await MainActor.run { [weak self] in
        guard let self else { return }
        if self.status == .sent {
          self.status = .ready
        }
      }
    }
  }

  /// Cancel any pending agent send task
  func cancelPendingAgentTask() {
    sendToAgentTask?.cancel()
    sendToAgentTask = nil
  }

  /// Mark the description as posted to MLS
  func markAsPosted() {
    guard status == .ready else { return }
    // PHASE 3: Persist to Supabase here
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
    // Cancel any pending tasks first
    cancelPendingAgentTask()

    generatedDescription = ""
    status = .draft
    errorMessage = nil
    showingOutput = false
    navigationPhase = .input
    // Phase 2: Reset additional state
    photos = []
    documents = []
    outputA = nil
    outputB = nil
    selectedVersion = nil
    refinementHistory = []
    currentRefinementPrompt = ""
    sessionId = UUID()
    // Report integration state
    generationPhase = .idle
    fetchedReports = []
    extractedFromImages = false
    // Draft persistence state
    currentDraftId = nil
    // Note: enableGeoWarehouse and enableMPAC are NOT reset (user preferences)
  }

  /// Navigate back to input screen (preserves all state)
  func navigateToInput() {
    navigationPhase = .input
  }

  /// Navigate to output screen (only if generation complete)
  func navigateToOutput() {
    guard showingOutput else { return }
    navigationPhase = .output
  }

  // MARK: - Phase 2: Photo Management

  /// Add a photo to the collection
  func addPhoto(_ photo: UploadedPhoto) {
    var newPhoto = photo
    newPhoto.sortOrder = photos.count
    photos.append(newPhoto)
  }

  /// Remove a photo by ID
  func removePhoto(id: UUID) {
    photos.removeAll { $0.id == id }
    // Recalculate sort orders
    for index in photos.indices {
      photos[index].sortOrder = index
    }
  }

  /// Reorder photos (move from source to destination)
  func reorderPhotos(from source: IndexSet, to destination: Int) {
    photos.move(fromOffsets: source, toOffset: destination)
    // Update sort orders after move
    for index in photos.indices {
      photos[index].sortOrder = index
    }
  }

  /// Set a photo as the hero (move to first position)
  func setHeroPhoto(id: UUID) {
    guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
    let photo = photos.remove(at: index)
    photos.insert(photo, at: 0)
    // Update sort orders
    for index in photos.indices {
      photos[index].sortOrder = index
    }
  }

  // MARK: - Phase 2: Document Management

  /// Add a document to the collection
  func addDocument(_ document: UploadedDocument) {
    documents.append(document)
  }

  /// Remove a document by ID
  func removeDocument(id: UUID) {
    documents.removeAll { $0.id == id }
  }

  // MARK: - Phase 2: Output Selection

  /// Select an output version (A or B)
  /// Logs preference for training data
  func selectVersion(_ version: OutputVersion) {
    // Deselect both first
    outputA?.isSelected = false
    outputB?.isSelected = false

    // Select the chosen version
    switch version {
    case .a:
      outputA?.isSelected = true
    case .b:
      outputB?.isSelected = true
    }

    selectedVersion = version

    // PHASE 3: Submit preference to training pipeline
    logPreference(version)
  }

  // MARK: - Phase 2: Refinement

  /// Submit a refinement request for the selected output
  func submitRefinement() async {
    guard
      !currentRefinementPrompt.trimmingCharacters(in: .whitespaces).isEmpty,
      let currentOutput = selectedOutput
    else { return }

    isRefining = true

    let request = RefinementRequest(prompt: currentRefinementPrompt)
    refinementHistory.append(request)

    // Log refinement for training data
    // PHASE 3: Submit to real training pipeline
    trainingService.logRefinement(
      sessionId: sessionId,
      selectedVersion: selectedVersion ?? .a,
      prompt: currentRefinementPrompt
    )

    // Use AI service for refinement
    // PHASE 3: Real AI refinement with prompt guidance
    do {
      let refinedOutput = try await aiService.refineOutput(
        currentOutput: currentOutput,
        prompt: currentRefinementPrompt
      )

      // Update the appropriate output
      if selectedVersion == .a {
        outputA = refinedOutput
      } else {
        outputB = refinedOutput
      }

      // Update legacy description for backward compatibility
      generatedDescription = refinedOutput.mlsFields.publicRemarks
    } catch {
      errorMessage = "Refinement failed: \(error.localizedDescription)"
    }

    currentRefinementPrompt = ""
    isRefining = false
  }

  // MARK: - Phase 2: Dual Output Generation

  /// Generate dual A/B outputs
  func generateDualOutput() async {
    guard canGenerate else { return }

    isLoading = true
    errorMessage = nil
    sessionId = UUID()
    fetchedReports = []
    extractedFromImages = false

    // Phase 1: Fetch enabled reports with mock delays
    if enableGeoWarehouse {
      generationPhase = .fetchingReport(.geoWarehouse)
      try? await Task.sleep(for: .milliseconds(800))
      fetchedReports.append(FetchedReport(type: .geoWarehouse))
    }

    if enableMPAC {
      generationPhase = .fetchingReport(.mpac)
      try? await Task.sleep(for: .milliseconds(800))
      fetchedReports.append(FetchedReport(type: .mpac))
    }

    // Phase 2: Extract from photos if any
    if !photos.isEmpty {
      generationPhase = .extractingFromImages
      try? await Task.sleep(for: .milliseconds(600))
      extractedFromImages = true
    }

    // Phase 3: Generate descriptions
    generationPhase = .generatingDescriptions

    // Build property details for AI service
    let propertyDetails = buildPropertyDetails()

    // Use AI service for dual output generation
    // PHASE 3: Real AI will generate unique content
    do {
      let (generatedA, generatedB) = try await aiService.generateDualOutput(
        photos: photos,
        documents: documents,
        propertyDetails: propertyDetails
      )

      outputA = generatedA
      outputB = generatedB

      // Also set legacy description for backward compatibility
      generatedDescription = generatedA.mlsFields.publicRemarks

      showingOutput = true
      status = .draft
      generationPhase = .complete
      navigationPhase = .output
    } catch {
      errorMessage = "Generation failed: \(error.localizedDescription)"
      generationPhase = .idle
    }

    isLoading = false
  }

  /// Copy a specific MLS field to clipboard
  func copyFieldToClipboard(_ fieldValue: String) {
    guard !fieldValue.isEmpty else { return }

    #if canImport(UIKit)
    UIPasteboard.general.string = fieldValue
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(fieldValue, forType: .string)
    #endif
  }

  /// Copy all MLS fields to clipboard
  func copyAllFieldsToClipboard() {
    guard let fields = selectedMLSFields else { return }
    let formattedText = fields.formattedForCopy()

    #if canImport(UIKit)
    UIPasteboard.general.string = formattedText
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(formattedText, forType: .string)
    #endif
  }

  // MARK: - Draft Persistence Methods

  /// Save the current state as a draft to SwiftData.
  /// Updates existing draft if `currentDraftId` is set, otherwise creates new.
  func saveDraft(to modelContext: ModelContext) throws {
    let inputSnapshot = createInputSnapshot()
    let outputSnapshot = showingOutput ? createOutputSnapshot() : nil

    let inputData = try JSONEncoder().encode(inputSnapshot)
    let outputData = try outputSnapshot.map { try JSONEncoder().encode($0) }

    let draftName = computeDraftName()

    if let draftId = currentDraftId {
      // Update existing draft
      let predicate = #Predicate<ListingGeneratorDraft> { $0.id == draftId }
      let descriptor = FetchDescriptor<ListingGeneratorDraft>(predicate: predicate)

      if let existingDraft = try modelContext.fetch(descriptor).first {
        existingDraft.update(
          inputStateData: inputData,
          outputStateData: outputData,
          hasOutput: showingOutput
        )
        existingDraft.updateName(draftName)
      }
    } else {
      // Create new draft
      let newDraft = ListingGeneratorDraft(
        name: draftName,
        inputStateData: inputData,
        outputStateData: outputData,
        hasOutput: showingOutput
      )
      modelContext.insert(newDraft)
      currentDraftId = newDraft.id
    }

    try modelContext.save()
  }

  /// Load state from a draft.
  /// Replaces current state with the draft's saved state.
  func loadDraft(_ draft: ListingGeneratorDraft, modelContext: ModelContext) throws {
    // Decode input snapshot
    let inputSnapshot = try JSONDecoder().decode(
      ListingGeneratorInputSnapshot.self,
      from: draft.inputStateData
    )

    // Apply input state
    applyInputSnapshot(inputSnapshot, modelContext: modelContext)

    // Decode and apply output snapshot if present
    if let outputData = draft.outputStateData {
      let outputSnapshot = try JSONDecoder().decode(
        ListingGeneratorOutputSnapshot.self,
        from: outputData
      )
      applyOutputSnapshot(outputSnapshot)
    } else {
      // Reset output state
      resetOutputState()
    }

    // Track the draft ID
    currentDraftId = draft.id
  }

  // MARK: Private

  private let trainingService = MockTrainingDataService()

  private let aiService: AIServiceProtocol

  /// Log preference selection for training data
  /// PHASE 3: Submit to backend training pipeline
  private func logPreference(_ version: OutputVersion) {
    let inputHash = buildPromptInput().hashValue.description

    // Log to training service
    trainingService.logPreference(
      sessionId: sessionId,
      selectedVersion: version,
      inputHash: inputHash
    )
  }

  /// Build PropertyDetails from current state
  private func buildPropertyDetails() -> PropertyDetails {
    switch inputMode {
    case .existingListing:
      guard let listing = selectedListing else {
        return PropertyDetails(address: "Unknown")
      }
      return PropertyDetails(
        address: listing.address,
        propertyType: listing.listingType.displayName,
        city: listing.city.isEmpty ? nil : listing.city,
        price: listing.price
      )

    case .manualEntry:
      return PropertyDetails(
        address: manualAddress,
        propertyType: manualPropertyType.isEmpty ? nil : manualPropertyType,
        additionalDetails: manualDetails.isEmpty ? nil : manualDetails
      )
    }
  }

  /// Create mock MLS fields with different tones
  /// PHASE 3: Replace with real AI generation
  private func createMockMLSFields(tone: OutputVersion) -> MLSFields {
    var fields = MLSFields()

    let address = propertyTitle

    // Property details (same for both)
    fields.propertyType = "Single Family"
    fields.yearBuilt = "2015"
    fields.squareFootage = "2,450"
    fields.lotSize = "0.25 acres"
    fields.bedrooms = "4"
    fields.bathrooms = "2.5"
    fields.stories = "2"
    fields.parkingSpaces = "2"
    fields.garageType = "Attached 2-Car"

    // Features (same for both)
    fields.heatingCooling = "Central Air, Forced Air"
    fields.flooring = "Hardwood, Tile, Carpet"
    fields.appliances = "Stainless Steel Refrigerator, Dishwasher, Microwave, Gas Range"
    fields.exteriorFeatures = "Covered Patio, Fenced Yard, Sprinkler System"
    fields.interiorFeatures = "Fireplace, High Ceilings, Walk-in Closets"
    fields.communityFeatures = "Pool, Tennis Courts, Playground"

    // Tone-specific content
    switch tone {
    case .a:
      // Professional & Formal
      fields.headline = "Exceptional Residence in Prime Location"
      fields.tagline = "Sophisticated living meets modern convenience"
      fields.publicRemarks = """
        This meticulously maintained \(fields.bedrooms)-bedroom, \(fields.bathrooms)-bathroom residence \
        at \(address) offers \(fields.squareFootage) square feet of refined living space. \
        Built in \(fields.yearBuilt), this two-story home features premium finishes throughout, \
        including hardwood flooring, high ceilings, and a gas fireplace. \

        The gourmet kitchen is equipped with stainless steel appliances and ample counter space. \
        The primary suite includes a spa-like bathroom and generous walk-in closet. \
        Additional amenities include a \(fields.garageType.lowercased()) garage, covered patio, \
        and professionally landscaped yard with sprinkler system. \

        Community features include pool, tennis courts, and playground access. \
        This property represents an exceptional opportunity for discerning buyers.
        """
      fields.privateRemarks = "Seller motivated. Pre-approved buyers preferred. Showing notice: 24 hours."
      fields.directions = "From Main St, turn east on Oak Ave, property on right after 0.5 miles."

    case .b:
      // Warm & Inviting
      fields.headline = "Welcome Home to Your Dream Property"
      fields.tagline = "Where memories are made and families thrive"
      fields.publicRemarks = """
        Imagine coming home to this beautiful \(fields.bedrooms)-bedroom, \(fields.bathrooms)-bathroom \
        family home at \(address)! With \(fields.squareFootage) square feet of warm, inviting living space, \
        there's room for everyone to spread out and make themselves at home. \

        You'll love gathering in the heart of the home - a sun-drenched kitchen with all the modern \
        amenities you need to create delicious meals for family and friends. Cozy up by the fireplace \
        on chilly evenings, or step outside to your covered patio and fenced backyard - perfect for \
        barbecues, playtime, and making memories. \

        The community offers amazing amenities including a sparkling pool, tennis courts, and playground. \
        This isn't just a house - it's the place where your family story continues. Come see it today!
        """
      fields.privateRemarks = "Sellers are relocating and flexible on timing. Family-friendly neighborhood."
      fields.directions = "Head east on Main St, turn right onto Oak Ave. Look for the welcoming front porch!"
    }

    return fields
  }

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

  // MARK: - Draft Snapshot Helpers

  /// Create a snapshot of the current input state
  private func createInputSnapshot() -> ListingGeneratorInputSnapshot {
    ListingGeneratorInputSnapshot(
      inputMode: inputMode.rawValue,
      selectedListingId: selectedListing?.id,
      selectedListingAddress: selectedListing?.address,
      manualAddress: manualAddress,
      manualPropertyType: manualPropertyType,
      manualDetails: manualDetails,
      photos: photos.map { PhotoSnapshot(from: $0) },
      documents: documents.map { DocumentSnapshot(from: $0) },
      enableGeoWarehouse: enableGeoWarehouse,
      enableMPAC: enableMPAC
    )
  }

  /// Create a snapshot of the current output state
  private func createOutputSnapshot() -> ListingGeneratorOutputSnapshot {
    ListingGeneratorOutputSnapshot(
      outputA: outputA.map { GeneratedOutputSnapshot(from: $0) },
      outputB: outputB.map { GeneratedOutputSnapshot(from: $0) },
      selectedVersion: selectedVersion?.rawValue,
      refinementHistory: refinementHistory.map { RefinementSnapshot(from: $0) },
      generatedDescription: generatedDescription,
      status: status.rawValue,
      sessionId: sessionId,
      fetchedReports: fetchedReports.map { FetchedReportSnapshot(from: $0) },
      extractedFromImages: extractedFromImages
    )
  }

  /// Apply an input snapshot to restore state
  private func applyInputSnapshot(_ snapshot: ListingGeneratorInputSnapshot, modelContext: ModelContext) {
    // Restore input mode
    inputMode = ListingInputMode(rawValue: snapshot.inputMode) ?? .existingListing

    // Restore listing selection
    if let listingId = snapshot.selectedListingId {
      // Try to fetch the listing from SwiftData
      let predicate = #Predicate<Listing> { $0.id == listingId }
      let descriptor = FetchDescriptor<Listing>(predicate: predicate)
      selectedListing = try? modelContext.fetch(descriptor).first
    } else {
      selectedListing = nil
    }

    // Restore manual entry fields
    manualAddress = snapshot.manualAddress
    manualPropertyType = snapshot.manualPropertyType
    manualDetails = snapshot.manualDetails

    // Restore photos and documents
    photos = snapshot.photos.map { $0.toUploadedPhoto() }
    documents = snapshot.documents.map { $0.toUploadedDocument() }

    // Restore report settings
    enableGeoWarehouse = snapshot.enableGeoWarehouse
    enableMPAC = snapshot.enableMPAC

    // Reset navigation to input
    navigationPhase = .input
  }

  /// Apply an output snapshot to restore state
  private func applyOutputSnapshot(_ snapshot: ListingGeneratorOutputSnapshot) {
    // Restore outputs
    outputA = snapshot.outputA?.toGeneratedOutput()
    outputB = snapshot.outputB?.toGeneratedOutput()

    // Restore selection
    if let versionRaw = snapshot.selectedVersion {
      selectedVersion = versionRaw == OutputVersion.a.rawValue ? .a : .b
    } else {
      selectedVersion = nil
    }

    // Restore refinement history
    refinementHistory = snapshot.refinementHistory.map { $0.toRefinementRequest() }

    // Restore legacy fields
    generatedDescription = snapshot.generatedDescription
    status = GeneratorStatus(rawValue: snapshot.status) ?? .draft

    // Restore session
    sessionId = snapshot.sessionId

    // Restore report data
    fetchedReports = snapshot.fetchedReports.map { $0.toFetchedReport() }
    extractedFromImages = snapshot.extractedFromImages

    // Mark as having output
    showingOutput = true
    generationPhase = .complete
  }

  /// Reset output state when loading a draft without output
  private func resetOutputState() {
    outputA = nil
    outputB = nil
    selectedVersion = nil
    refinementHistory = []
    generatedDescription = ""
    status = .draft
    showingOutput = false
    generationPhase = .idle
    fetchedReports = []
    extractedFromImages = false
  }

  /// Compute a meaningful name for the draft
  private func computeDraftName() -> String {
    switch inputMode {
    case .existingListing:
      if let address = selectedListing?.address, !address.isEmpty {
        return address
      }

    case .manualEntry:
      if !manualAddress.isEmpty {
        return manualAddress
      }
    }
    return "Untitled Draft"
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
