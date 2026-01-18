//
//  ListingGeneratorView.swift
//  Dispatch
//
//  Main full-view workspace for AI listing generation.
//  Implements a two-screen navigation flow:
//  - Screen 1 (Input): Property selection, photo/document upload, report toggles
//  - Screen 2 (Output): A/B comparison, refinement, MLS fields
//
//  Platform-adaptive layout:
//  - macOS/iPad landscape: Side-by-side panels (both screens visible)
//  - iOS/iPad portrait: Navigation-based two-screen flow
//

import SwiftData
import SwiftUI

// MARK: - ListingGeneratorView

/// Full-view workspace for AI listing generation.
/// Two-screen navigation: Input -> Output (via Generate button).
/// State is preserved when navigating back from output to input.
struct ListingGeneratorView: View {

  // MARK: Lifecycle

  init(preselectedListingId: UUID? = nil, preselectedDraftId: UUID? = nil) {
    self.preselectedListingId = preselectedListingId
    self.preselectedDraftId = preselectedDraftId
  }

  // MARK: Internal

  var body: some View {
    // NOTE: Do NOT wrap in NavigationStack - this view is presented inside
    // the parent NavigationStack via AppDestinationsModifier. Nesting
    // NavigationStacks causes blank screen rendering issues.
    content
      .navigationTitle(navigationTitle)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.large)
    #endif
      .task {
        // Skip loading if data is already cached from previous navigation
        guard isInitialLoading else { return }
        await loadPreselectedDraft()
        await loadPreselectedListing()
        await loadListings()
        isInitialLoading = false
      }
      .onAppear { overlayState.hide(reason: .settingsScreen) }
      .onDisappear { overlayState.show(reason: .settingsScreen) }
      .onChange(of: state.showingOutput) { _, showingOutput in
        // Auto-save draft after successful generation
        if showingOutput {
          saveDraftAfterGeneration()
        }
      }
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @EnvironmentObject private var overlayState: AppOverlayState

  @State private var state = ListingGeneratorState()
  @State private var listings: [Listing] = []
  @State private var isInitialLoading = true

  private let preselectedListingId: UUID?
  private let preselectedDraftId: UUID?

  /// Dynamic navigation title based on current phase
  private var navigationTitle: String {
    switch state.navigationPhase {
    case .input:
      "Listing Generator"
    case .output:
      "Generated Listing"
    }
  }

  /// Whether to use split-view layout (both screens visible)
  private var useSplitLayout: Bool {
    #if os(macOS)
    true
    #else
    horizontalSizeClass == .regular
    #endif
  }

  @ViewBuilder
  private var content: some View {
    if isInitialLoading {
      loadingContent
    } else {
      GeometryReader { geometry in
        #if os(macOS)
        // macOS: Always use split layout
        splitLayout
          .tint(DS.Colors.accent)
        #else
        // iOS/iPadOS: Adaptive based on size class and orientation
        if horizontalSizeClass == .regular, geometry.size.width > 700 {
          // iPad landscape: Split layout
          splitLayout
            .tint(DS.Colors.accent)
        } else {
          // iPhone / iPad portrait: Two-screen navigation flow
          navigationLayout
            .tint(DS.Colors.accent)
        }
        #endif
      }
    }
  }

  /// Loading state shown during initial data load
  @ViewBuilder
  private var loadingContent: some View {
    VStack(spacing: DS.Spacing.md) {
      ProgressView()
        .controlSize(.regular)
      Text("Loading...")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.Colors.Background.grouped)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading listing generator")
  }

  // MARK: - Split Layout (macOS / iPad Landscape)

  @ViewBuilder
  private var splitLayout: some View {
    HStack(alignment: .top, spacing: 0) {
      // Input panel (always visible)
      inputScreen
        .frame(maxWidth: 450)

      Divider()

      // Output panel (shows placeholder until generation complete)
      if state.showingOutput {
        outputScreen
      } else {
        outputPlaceholder
          .frame(maxWidth: .infinity)
      }
    }
  }

  // MARK: - Navigation Layout (iPhone / iPad Portrait)

  @ViewBuilder
  private var navigationLayout: some View {
    // Show the appropriate screen based on navigation phase
    switch state.navigationPhase {
    case .input:
      inputScreen
        .transition(.move(edge: .leading))

    case .output:
      outputScreen
        .transition(.move(edge: .trailing))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              withAnimation(.easeInOut(duration: 0.25)) {
                state.navigateToInput()
              }
            } label: {
              HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chevron.left")
                  .fontWeight(.semibold)
                Text("Edit")
              }
            }
            .accessibilityLabel("Back to input")
            .accessibilityHint("Return to edit property details and photos")
          }
        }
    }
  }

  // MARK: - Input Screen

  @ViewBuilder
  private var inputScreen: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        inputSections
        generateButton
      }
      .padding(DS.Spacing.lg)
    }
    .defaultScrollAnchor(.top)
    #if os(macOS)
      .contentMargins(.bottom, DS.Spacing.bottomToolbarHeight, for: .scrollContent)
    #else
      .contentMargins(.bottom, DS.Spacing.floatingButtonScrollInset, for: .scrollContent)
    #endif
      .background(DS.Colors.Background.grouped)
  }

  // MARK: - Output Screen

  @ViewBuilder
  private var outputScreen: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        outputSections
      }
      .padding(DS.Spacing.lg)
    }
    .defaultScrollAnchor(.top)
    #if os(macOS)
      .contentMargins(.bottom, DS.Spacing.bottomToolbarHeight, for: .scrollContent)
    #else
      .contentMargins(.bottom, DS.Spacing.floatingButtonScrollInset, for: .scrollContent)
    #endif
      .background(DS.Colors.Background.primary)
  }

  // MARK: - Input Sections

  @ViewBuilder
  private var inputSections: some View {
    VStack(spacing: DS.Spacing.sectionSpacing) {
      // Photo upload section
      PhotoUploadSection(
        photos: $state.photos,
        onAdd: { photo in state.addPhoto(photo) },
        onRemove: { id in state.removePhoto(id: id) },
        onReorder: { source, dest in state.reorderPhotos(from: source, to: dest) },
        onSetHero: { id in state.setHeroPhoto(id: id) }
      )

      // Document upload section
      DocumentUploadSection(
        documents: $state.documents,
        onAdd: { doc in state.addDocument(doc) },
        onRemove: { id in state.removeDocument(id: id) }
      )

      // Property input section
      PropertyInputSection(
        state: state,
        listings: listings
      )

      // Report toggle section
      ReportToggleSection(
        enableGeoWarehouse: $state.enableGeoWarehouse,
        enableMPAC: $state.enableMPAC
      )
    }
  }

  // MARK: - Generate Button

  @ViewBuilder
  private var generateButton: some View {
    Button {
      Task {
        await state.generateDualOutput()
      }
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        if state.isLoading {
          GenerationProgressView(phase: state.generationPhase)
        } else {
          Text("Generate Listing")
            .font(DS.Typography.headline)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!state.canGenerate || state.isLoading)
    .accessibilityLabel(state.isLoading ? state.generationPhase.displayText : "Generate listing")
    .accessibilityHint(
      state.canGenerate
        ? "Double tap to generate AI listing"
        : "Select a listing or enter an address first"
    )
    #if os(macOS)
    .keyboardShortcut(.return, modifiers: .command)
    #endif
  }

  // MARK: - Output Sections

  @ViewBuilder
  private var outputSections: some View {
    VStack(spacing: DS.Spacing.sectionSpacing) {
      // Fetched reports section (at top of output)
      if !state.fetchedReports.isEmpty || state.extractedFromImages {
        fetchedDataSection
      }

      // A/B Comparison Section
      OutputComparisonSection(
        outputA: state.outputA,
        outputB: state.outputB,
        selectedVersion: Binding(
          get: { state.selectedVersion },
          set: { newValue in
            if let version = newValue {
              state.selectVersion(version)
            }
          }
        ),
        onSelect: { version in
          state.selectVersion(version)
        }
      )

      // Refinement Section (applies to selected description)
      if state.selectedOutput != nil {
        RefinementSection(
          prompt: $state.currentRefinementPrompt,
          history: state.refinementHistory,
          isRefining: state.isRefining,
          hasSelectedOutput: state.selectedOutput != nil,
          onSubmit: {
            Task {
              await state.submitRefinement()
            }
          }
        )
      }

      // MLS Fields Section - ALWAYS at bottom, uses outputA as canonical source
      mlsFieldsSection

      // Error message
      if let error = state.errorMessage {
        errorView(error)
      }
    }
  }

  @ViewBuilder
  private var mlsFieldsSection: some View {
    // Use outputA as the canonical MLS fields source
    // MLS fields are property metadata (beds, baths, etc.) and don't vary between A/B versions
    if let outputA = state.outputA {
      MLSFieldsSection(
        fields: Binding(
          get: { outputA.mlsFields },
          set: { newFields in
            // Update outputA only - it's the canonical source for MLS fields
            state.outputA?.mlsFields = newFields
          }
        ),
        originalFields: state.originalMLSFields,
        sessionId: state.sessionId
      )
    }
  }

  @ViewBuilder
  private var fetchedDataSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      Text("Sources")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      // Photo extraction indicator
      if state.extractedFromImages {
        HStack(spacing: DS.Spacing.sm) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(DS.Colors.success)
            .accessibilityHidden(true)

          Image(systemName: "photo.on.rectangle.angled")
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(DS.Colors.Text.secondary)
            .accessibilityHidden(true)

          Text("Extracted from \(state.photos.count) photo\(state.photos.count == 1 ? "" : "s")")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.primary)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Information extracted from \(state.photos.count) photos")
      }

      // Fetched reports
      ForEach(state.fetchedReports.indices, id: \.self) { index in
        FetchedReportRow(
          report: state.fetchedReports[index],
          onToggleExpand: {
            withAnimation(.easeInOut(duration: 0.2)) {
              state.fetchedReports[index].isExpanded.toggle()
            }
          }
        )
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: - Output Placeholder

  @ViewBuilder
  private var outputPlaceholder: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.lg) {
        Spacer(minLength: DS.Spacing.xxxl)

        Image(systemName: "sparkles")
          .font(.system(size: 48))
          .foregroundStyle(DS.Colors.Text.tertiary)
          .accessibilityHidden(true)

        Text("Generate a listing to see output here")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.secondary)
          .multilineTextAlignment(.center)

        Text("Add photos and property details, then tap Generate")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .multilineTextAlignment(.center)

        Spacer(minLength: DS.Spacing.xxxl)
      }
      .frame(maxWidth: .infinity)
      .padding(DS.Spacing.lg)
    }
    .background(DS.Colors.Background.primary)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Output area. Generate a listing to see results here. Add photos and property details, then tap Generate."
    )
  }

  // MARK: - Error View

  @ViewBuilder
  private func errorView(_ message: String) -> some View {
    HStack(spacing: DS.Spacing.sm) {
      Image(systemName: DS.Icons.Alert.warning)
        .foregroundStyle(DS.Colors.destructive)

      Text(message)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.destructive)

      Spacer()

      Button {
        state.errorMessage = nil
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(DS.Colors.Text.tertiary)
      }
      .buttonStyle(.plain)
      .frame(width: DS.Spacing.minTouchTarget, height: DS.Spacing.minTouchTarget)
      .contentShape(Rectangle())
      .accessibilityLabel("Dismiss error")
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.destructive.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
  }

  // MARK: - Data Loading

  private func loadPreselectedListing() async {
    guard let listingId = preselectedListingId else { return }

    let descriptor = FetchDescriptor<Listing>(
      predicate: #Predicate { $0.id == listingId }
    )

    do {
      let results = try modelContext.fetch(descriptor)
      if let listing = results.first {
        state.selectedListing = listing
        state.inputMode = .existingListing
      }
    } catch {
      // PHASE 3: Handle error appropriately - add proper error logging
      // swiftlint:disable:next no_direct_standard_out_logs
      print("Failed to fetch listing: \(error)")
    }
  }

  private func loadListings() async {
    let descriptor = FetchDescriptor<Listing>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )

    do {
      listings = try modelContext.fetch(descriptor)
    } catch {
      // PHASE 3: Handle error appropriately - add proper error logging
      // swiftlint:disable:next no_direct_standard_out_logs
      print("Failed to fetch listings: \(error)")
    }
  }

  private func loadPreselectedDraft() async {
    guard let draftId = preselectedDraftId else { return }

    let descriptor = FetchDescriptor<ListingGeneratorDraft>(
      predicate: #Predicate { $0.id == draftId }
    )

    do {
      let results = try modelContext.fetch(descriptor)
      if let draft = results.first {
        try state.loadDraft(draft, modelContext: modelContext)
      }
    } catch {
      // PHASE 3: Handle error appropriately - add proper error logging
      // swiftlint:disable:next no_direct_standard_out_logs
      print("Failed to load draft: \(error)")
    }
  }

  private func saveDraftAfterGeneration() {
    do {
      try state.saveDraft(to: modelContext)
    } catch {
      // PHASE 3: Handle error appropriately - add proper error logging
      // swiftlint:disable:next no_direct_standard_out_logs
      print("Failed to save draft: \(error)")
    }
  }
}

// MARK: - Preview

#Preview("Listing Generator - Input") {
  PreviewShell { _ in
    ListingGeneratorView()
  }
}

#Preview("Listing Generator - Output") {
  PreviewShell { _ in
    ListingGeneratorView()
  }
}
