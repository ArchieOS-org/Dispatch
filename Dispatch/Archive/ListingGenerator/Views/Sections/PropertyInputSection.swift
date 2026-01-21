//
//  PropertyInputSection.swift
//  Dispatch
//
//  Property input section for the listing generator.
//  Supports both existing listing selection and manual property entry.
//

import SwiftData
import SwiftUI

// MARK: - PropertyInputSection

/// Section for providing property information.
/// Offers two modes: select from existing listings or manual entry.
struct PropertyInputSection: View {

  // MARK: Internal

  @Bindable var state: ListingGeneratorState

  let listings: [Listing]

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      sectionHeader

      // Mode picker
      modePicker

      // Content based on mode
      switch state.inputMode {
      case .existingListing:
        listingPickerContent
      case .manualEntry:
        manualEntryContent
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: Private

  @State private var showingListingPicker = false

  @ViewBuilder
  private var sectionHeader: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text("Property Information")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("Provide details about the property")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
  }

  @ViewBuilder
  private var modePicker: some View {
    Picker("Input Mode", selection: $state.inputMode) {
      ForEach(ListingInputMode.allCases) { mode in
        Label(mode.title, systemImage: mode.icon)
          .tag(mode)
      }
    }
    .pickerStyle(.segmented)
  }

  // MARK: - Existing Listing Mode

  @ViewBuilder
  private var listingPickerContent: some View {
    if let listing = state.selectedListing {
      // Selected listing display
      selectedListingCard(listing)
    } else {
      // Listing picker button
      listingPickerButton
    }
  }

  @ViewBuilder
  private var listingPickerButton: some View {
    if listings.isEmpty {
      // No listings available
      VStack(spacing: DS.Spacing.md) {
        Image(systemName: DS.Icons.Entity.listing)
          .font(.system(size: 32))
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
      .padding(.vertical, DS.Spacing.lg)
    } else {
      // Listing picker button
      Button(action: { showingListingPicker = true }) {
        HStack {
          Image(systemName: DS.Icons.Entity.listing)
            .font(.system(size: 20))
            .foregroundStyle(DS.Colors.accent)

          Text("Select a Listing")
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.Text.primary)

          Spacer()

          Image(systemName: DS.Icons.Navigation.forward)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.Text.tertiary)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
      }
      .buttonStyle(.plain)
      .sheet(isPresented: $showingListingPicker) {
        ListingPickerSheet(
          listings: listings,
          selectedListing: $state.selectedListing,
          isPresented: $showingListingPicker
        )
      }
    }
  }

  // MARK: - Manual Entry Mode

  @ViewBuilder
  private var manualEntryContent: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
      // Property address (required)
      manualField(
        title: "Property Address",
        placeholder: "Enter property address",
        text: $state.manualAddress,
        isRequired: true
      )

      // Property type
      manualField(
        title: "Property Type",
        placeholder: "e.g., Single Family, Condo, Townhouse",
        text: $state.manualPropertyType
      )

      // Property details grid
      propertyDetailsGrid

      // Additional details
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Key Features & Selling Points")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        ZStack(alignment: .topLeading) {
          TextEditor(text: $state.manualDetails)
            .font(DS.Typography.body)
            .frame(minHeight: DS.Spacing.noteInputMinHeight)
            .scrollContentBackground(.hidden)
            .padding(DS.Spacing.sm)

          // Placeholder using opacity pattern for stable layout
          Text("Unique features, recent upgrades, neighborhood highlights...")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.placeholder)
            .padding(.horizontal, DS.Spacing.sm + 4)
            .padding(.vertical, DS.Spacing.sm + 8)
            .allowsHitTesting(false)
            .opacity(state.manualDetails.isEmpty ? 1 : 0)
        }
        .background(DS.Colors.Background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
        .overlay(
          RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
            .stroke(DS.Colors.border, lineWidth: 1)
        )
      }
    }
  }

  @ViewBuilder
  private var propertyDetailsGrid: some View {
    // PHASE 3: Add more structured manual entry fields
    // For now, the free-form text area handles additional details
    EmptyView()
  }

  @ViewBuilder
  private func selectedListingCard(_ listing: Listing) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
          Text(listing.address.titleCased())
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.Text.primary)

          HStack(spacing: DS.Spacing.sm) {
            if !listing.city.isEmpty {
              Text(listing.city.titleCased())
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.Text.secondary)
            }
            ListingTypePill(type: listing.listingType)
          }
        }

        Spacer()

        Button {
          withAnimation {
            state.selectedListing = nil
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(DS.Colors.Text.tertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear selection")
      }

      Divider()

      Button(action: { showingListingPicker = true }) {
        Text("Change Listing")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.accent)
      }
      .buttonStyle(.plain)
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.Background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
    .sheet(isPresented: $showingListingPicker) {
      ListingPickerSheet(
        listings: listings,
        selectedListing: $state.selectedListing,
        isPresented: $showingListingPicker
      )
    }
  }

  @ViewBuilder
  private func manualField(
    title: String,
    placeholder: String,
    text: Binding<String>,
    isRequired: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
      HStack(spacing: DS.Spacing.xxs) {
        Text(title)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)

        if isRequired {
          Text("*")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.destructive)
        }
      }

      TextField(placeholder, text: text)
        .textFieldStyle(.roundedBorder)
    }
  }

}

// MARK: - ListingPickerSheet

/// Sheet for selecting from available listings.
struct ListingPickerSheet: View {

  let listings: [Listing]
  @Binding var selectedListing: Listing?
  @Binding var isPresented: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(listings) { listing in
            ListingPickerRow(
              listing: listing,
              isSelected: selectedListing?.id == listing.id
            ) {
              withAnimation {
                selectedListing = listing
                isPresented = false
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
        .padding(DS.Spacing.lg)
      }
      .background(DS.Colors.Background.grouped)
      .navigationTitle("Select Listing")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              isPresented = false
            }
          }
        }
    }
  }
}

// MARK: - Preview

#Preview("Property Input - Empty Listing Selection") {
  PreviewShell { _ in
    let state = ListingGeneratorState()

    PropertyInputSection(
      state: state,
      listings: []
    )
    .padding()
    .background(DS.Colors.Background.grouped)
  }
}

#Preview("Property Input - Manual Entry") {
  PreviewShell { _ in
    let state = ListingGeneratorState()
    state.inputMode = .manualEntry
    state.manualAddress = "123 Main Street"
    state.manualPropertyType = "Single Family Home"

    return PropertyInputSection(
      state: state,
      listings: []
    )
    .padding()
    .background(DS.Colors.Background.grouped)
  }
}
