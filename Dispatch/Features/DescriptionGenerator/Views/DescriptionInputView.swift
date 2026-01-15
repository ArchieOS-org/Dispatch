//
//  DescriptionInputView.swift
//  Dispatch
//
//  Screen 1 of the Description Generator: Input collection.
//  Supports both existing listing selection and manual property entry.
//

import SwiftData
import SwiftUI

// MARK: - DescriptionInputView

/// First screen of the description generator flow.
/// Users can either select an existing listing or manually enter property details.
struct DescriptionInputView: View {

  // MARK: Internal

  @Bindable var state: DescriptionGeneratorState
  let listings: [Listing]
  let onGenerate: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        // Header
        headerSection

        // Mode Picker
        modePickerSection

        // Input content based on mode
        switch state.inputMode {
        case .existingListing:
          listingSelectionSection
        case .manualEntry:
          manualEntrySection
        }

        // Error message
        if let error = state.errorMessage {
          errorView(error)
        }

        // Generate button
        generateButton
      }
      .padding(DS.Spacing.lg)
    }
  }

  // MARK: Private

  @ViewBuilder
  private var headerSection: some View {
    VStack(spacing: DS.Spacing.sm) {
      Text("Generate Description")
        .font(DS.Typography.title)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("Create a compelling listing description powered by AI")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, DS.Spacing.md)
  }

  @ViewBuilder
  private var modePickerSection: some View {
    Picker("Input Mode", selection: $state.inputMode) {
      ForEach(DescriptionInputMode.allCases) { mode in
        Label(mode.title, systemImage: mode.icon)
          .tag(mode)
      }
    }
    .pickerStyle(.segmented)
  }

  @ViewBuilder
  private var listingSelectionSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      Text("Select a Listing")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      if listings.isEmpty {
        emptyListingsView
      } else {
        listingsListView
      }
    }
  }

  @ViewBuilder
  private var emptyListingsView: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icons.Entity.listing)
        .font(.system(size: 40))
        .foregroundStyle(DS.Colors.Text.tertiary)

      Text("No listings available")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.secondary)

      Text("Switch to Manual Entry to describe a property")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DS.Spacing.xxl)
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
  }

  @ViewBuilder
  private var listingsListView: some View {
    VStack(spacing: 0) {
      ForEach(listings) { listing in
        ListingPickerRow(
          listing: listing,
          isSelected: state.selectedListing?.id == listing.id
        ) {
          withAnimation(.easeInOut(duration: 0.2)) {
            state.selectedListing = listing
          }
        }

        if listing.id != listings.last?.id {
          Divider()
            .padding(.leading, DS.Spacing.xxl + DS.Spacing.md)
        }
      }
    }
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
  }

  @ViewBuilder
  private var manualEntrySection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
      // Address field (required)
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Address")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        TextField("Enter property address", text: $state.manualAddress)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel("Property address")
      }

      // Property type field (optional)
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Property Type (Optional)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        TextField("e.g., Luxury Condo, Family Home", text: $state.manualPropertyType)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel("Property type, optional")
      }

      // Details field (optional)
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Additional Details (Optional)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        TextEditor(text: $state.manualDetails)
          .font(DS.Typography.body)
          .frame(minHeight: DS.Spacing.noteInputMinHeight)
          .scrollContentBackground(.hidden)
          .padding(DS.Spacing.sm)
          .background(DS.Colors.Background.card)
          .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
          .overlay(
            RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
              .stroke(DS.Colors.border, lineWidth: 1)
          )
          .accessibilityLabel("Additional property details")

        Text("Square footage, bedrooms, unique features, neighborhood highlights...")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
      }
    }
  }

  @ViewBuilder
  private func errorView(_ message: String) -> some View {
    HStack(spacing: DS.Spacing.sm) {
      Image(systemName: DS.Icons.Alert.warning)
        .foregroundStyle(DS.Colors.destructive)

      Text(message)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.destructive)
    }
    .padding(DS.Spacing.md)
    .frame(maxWidth: .infinity)
    .background(DS.Colors.destructive.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
  }

  @ViewBuilder
  private var generateButton: some View {
    Button(action: onGenerate) {
      HStack(spacing: DS.Spacing.sm) {
        if state.isLoading {
          ProgressView()
            .progressViewStyle(.circular)
            #if os(iOS)
            .tint(.white)
            #endif
        }
        Text(state.isLoading ? "Generating..." : "Generate Description")
          .font(DS.Typography.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: DS.Spacing.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!state.canGenerate)
    .padding(.top, DS.Spacing.md)
    .accessibilityLabel(state.isLoading ? "Generating description" : "Generate description")
    .accessibilityHint(state.canGenerate ? "Double tap to generate AI description" : "Select a listing or enter an address first")
  }
}

// MARK: - Preview

#Preview("Input View - Existing Listing") {
  PreviewShell { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []
    let state = DescriptionGeneratorState()

    DescriptionInputView(
      state: state,
      listings: listings,
      onGenerate: { }
    )
  }
}

#Preview("Input View - Manual Entry") {
  PreviewShell { _ in
    let state = DescriptionGeneratorState()
    state.inputMode = .manualEntry

    return DescriptionInputView(
      state: state,
      listings: [],
      onGenerate: { }
    )
  }
}
