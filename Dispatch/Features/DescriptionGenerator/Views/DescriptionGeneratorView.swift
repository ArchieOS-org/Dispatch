//
//  DescriptionGeneratorView.swift
//  Dispatch
//
//  Main full-view workspace for AI listing description generation.
//  Replaces the sheet-based DescriptionGeneratorSheet with a
//  navigation-based full-screen experience.
//
//  Platform-adaptive layout:
//  - macOS: Side-by-side input/output panels
//  - iPad landscape: Two-column adaptive
//  - iOS/iPad portrait: Stacked sections
//

import SwiftData
import SwiftUI

// MARK: - DescriptionGeneratorView

/// Full-view workspace for AI listing description generation.
/// Provides photo/document upload, property input, A/B output comparison,
/// and prompt-based refinement.
struct DescriptionGeneratorView: View {

  // MARK: Lifecycle

  init(preselectedListingId: UUID? = nil) {
    self.preselectedListingId = preselectedListingId
  }

  // MARK: Internal

  var body: some View {
    // NOTE: Do NOT wrap in NavigationStack - this view is presented inside
    // the parent NavigationStack via AppDestinationsModifier. Nesting
    // NavigationStacks causes blank screen rendering issues.
    content
      .navigationTitle("Description Generator")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.large)
    #endif
      .task {
        await loadPreselectedListing()
        await loadListings()
      }
      .onAppear { overlayState.hide(reason: .settingsScreen) }
      .onDisappear { overlayState.show(reason: .settingsScreen) }
  }

  // MARK: Private

  private let preselectedListingId: UUID?

  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @EnvironmentObject private var overlayState: AppOverlayState

  @State private var state = DescriptionGeneratorState()
  @State private var listings: [Listing] = []

  @ViewBuilder
  private var content: some View {
    GeometryReader { geometry in
      #if os(macOS)
      // macOS: Always use side-by-side layout
      macOSLayout
        .tint(DS.Colors.accent)
      #else
      // iOS/iPadOS: Adaptive based on size class and orientation
      if horizontalSizeClass == .regular, geometry.size.width > 700 {
        iPadLandscapeLayout
          .tint(DS.Colors.accent)
      } else {
        mobileLayout
          .tint(DS.Colors.accent)
      }
      #endif
    }
  }

  // MARK: - Platform Layouts

  #if os(macOS)
  @ViewBuilder
  private var macOSLayout: some View {
    HSplitView {
      // Input panel
      inputPanel
        .frame(minWidth: 350, idealWidth: 450, maxWidth: 550)

      // Output panel
      outputPanel
        .frame(minWidth: 400)
    }
  }
  #endif

  @ViewBuilder
  private var iPadLandscapeLayout: some View {
    HStack(alignment: .top, spacing: 0) {
      // Input panel
      inputPanel
        .frame(maxWidth: 450)

      Divider()

      // Output panel
      outputPanel
    }
  }

  @ViewBuilder
  private var mobileLayout: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        // Input sections
        inputSections

        // Generate button
        generateButton

        // Output section
        if state.showingOutput {
          outputSections
        } else {
          outputPlaceholder
        }
      }
      .padding(DS.Spacing.lg)
    }
    // Add bottom margin to clear floating buttons on iOS
    .contentMargins(.bottom, DS.Spacing.floatingButtonScrollInset, for: .scrollContent)
    .background(DS.Colors.Background.grouped)
  }

  // MARK: - Panels (for split layouts)

  @ViewBuilder
  private var inputPanel: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        inputSections
        generateButton
      }
      .padding(DS.Spacing.lg)
    }
    #if os(macOS)
    .contentMargins(.bottom, DS.Spacing.bottomToolbarHeight, for: .scrollContent)
    #endif
    .background(DS.Colors.Background.grouped)
  }

  @ViewBuilder
  private var outputPanel: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        if state.showingOutput {
          outputSections
        } else {
          outputPlaceholder
        }
      }
      .padding(DS.Spacing.lg)
    }
    #if os(macOS)
    .contentMargins(.bottom, DS.Spacing.bottomToolbarHeight, for: .scrollContent)
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
          ProgressView()
            .controlSize(.small)
          #if os(iOS)
            .tint(.white)
          #endif
        }
        Text(state.isLoading ? "Generating..." : "Generate Descriptions")
          .font(DS.Typography.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!state.canGenerate || state.isLoading)
    .accessibilityLabel(state.isLoading ? "Generating descriptions" : "Generate descriptions")
    .accessibilityHint(
      state.canGenerate
        ? "Double tap to generate AI descriptions"
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

      // MLS Fields Section (only when output is selected)
      if state.selectedOutput != nil {
        mlsFieldsSection

        // Refinement Section
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

      // Error message
      if let error = state.errorMessage {
        errorView(error)
      }
    }
  }

  @ViewBuilder
  private var mlsFieldsSection: some View {
    if let output = state.selectedOutput {
      MLSFieldsSection(
        fields: Binding(
          get: { output.mlsFields },
          set: { newFields in
            if state.selectedVersion == .a {
              state.outputA?.mlsFields = newFields
            } else if state.selectedVersion == .b {
              state.outputB?.mlsFields = newFields
            }
          }
        ),
        originalFields: state.originalMLSFields,
        sessionId: state.sessionId
      )
    }
  }

  @ViewBuilder
  private var versionSelectorSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      Text("Compare Versions")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("Select your preferred tone and style")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)

      if let outputA = state.outputA, let outputB = state.outputB {
        HStack(spacing: DS.Spacing.md) {
          versionCard(output: outputA)
          versionCard(output: outputB)
        }
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: - Output Placeholder

  @ViewBuilder
  private var outputPlaceholder: some View {
    VStack(spacing: DS.Spacing.lg) {
      Image(systemName: "sparkles")
        .font(.system(size: 48))
        .foregroundStyle(DS.Colors.Text.tertiary)

      Text("Generate a description to see output here")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
        .multilineTextAlignment(.center)

      Text("Add photos and property details, then tap Generate")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DS.Spacing.xxxl)
    .padding(.horizontal, DS.Spacing.lg)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Output placeholder. Generate a description to see output here. Add photos and property details, then tap Generate."
    )
  }

  @ViewBuilder
  private func versionCard(output: GeneratedOutput) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        state.selectVersion(output.version)
      }
    } label: {
      VStack(spacing: DS.Spacing.sm) {
        // Version label
        Text(output.version.shortLabel)
          .font(DS.Typography.largeTitle)
          .fontWeight(.bold)
          .foregroundStyle(output.isSelected ? DS.Colors.accent : DS.Colors.Text.primary)

        // Tone description
        Text(output.version.toneDescription)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
          .multilineTextAlignment(.center)

        // Selection indicator
        if output.isSelected {
          HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 14))
            Text("Selected")
              .font(DS.Typography.captionSecondary)
              .fontWeight(.semibold)
          }
          .foregroundStyle(DS.Colors.accent)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(DS.Spacing.lg)
      .background(output.isSelected ? DS.Colors.accent.opacity(0.08) : DS.Colors.Background.secondary)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium)
          .stroke(output.isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: output.isSelected ? 2 : 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(output.version.rawValue), \(output.version.toneDescription)")
    .accessibilityHint(output.isSelected ? "Currently selected" : "Double tap to select")
    .accessibilityAddTraits(output.isSelected ? .isSelected : [])
  }

  @ViewBuilder
  private func selectedOutputPreview(_ output: GeneratedOutput) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Header
      HStack {
        Text("Preview")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Spacer()

        DescriptionStatusChip(status: state.status)
      }

      // Headline
      Text(output.mlsFields.headline)
        .font(DS.Typography.title3)
        .foregroundStyle(DS.Colors.Text.primary)

      // Tagline
      if !output.mlsFields.tagline.isEmpty {
        Text(output.mlsFields.tagline)
          .font(DS.Typography.callout)
          .foregroundStyle(DS.Colors.Text.secondary)
          .italic()
      }

      Divider()

      // Public remarks preview
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Public Remarks")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)

        Text(output.mlsFields.publicRemarks)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)
          .lineLimit(8)
      }

      // Property details summary
      propertyDetailsSummary(output.mlsFields)
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  @ViewBuilder
  private func propertyDetailsSummary(_ fields: MLSFields) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Divider()

      Text("Property Details")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)

      // Quick stats row
      HStack(spacing: DS.Spacing.lg) {
        detailPill(icon: "bed.double", value: fields.bedrooms, label: "Beds")
        detailPill(icon: "shower", value: fields.bathrooms, label: "Baths")
        detailPill(icon: "square.dashed", value: fields.squareFootage, label: "Sq Ft")
        detailPill(icon: "calendar", value: fields.yearBuilt, label: "Built")
      }
    }
  }

  @ViewBuilder
  private func detailPill(icon: String, value: String, label: String) -> some View {
    VStack(spacing: DS.Spacing.xxs) {
      Image(systemName: icon)
        .font(.system(size: 16))
        .foregroundStyle(DS.Colors.Text.secondary)

      Text(value)
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text(label)
        .font(DS.Typography.captionSecondary)
        .foregroundStyle(DS.Colors.Text.tertiary)
    }
    .frame(maxWidth: .infinity)
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
}

// MARK: - Preview

#Preview("Description Generator - Empty") {
  PreviewShell { _ in
    DescriptionGeneratorView()
  }
}

#Preview("Description Generator - With Output") {
  PreviewShell { _ in
    DescriptionGeneratorView()
  }
}
