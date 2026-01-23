//
//  StandardListingPickerSheet.swift
//  Dispatch
//
//  Standardized sheet for selecting a listing.
//

import SwiftUI

// MARK: - StandardListingPickerSheet

/// Standardized sheet for selecting a listing from a list.
/// Includes a "None" option for deselection.
struct StandardListingPickerSheet: View {

  // MARK: Lifecycle

  init(
    selectedListing: Binding<Listing?>,
    listings: [Listing],
    onDismiss: @escaping () -> Void
  ) {
    _selectedListing = selectedListing
    self.listings = listings
    self.onDismiss = onDismiss
  }

  // MARK: Internal

  @Binding var selectedListing: Listing?

  let listings: [Listing]
  var onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      StandardScreen(
        title: "Select Listing",
        layout: .column,
        scroll: .disabled
      ) {
        List {
          noneOption
          ForEach(listings) { listing in
            listingRow(listing)
          }
        }
        .listStyle(.plain)
      } toolbarContent: {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss()
          }
        }
      }
    }
    #if os(iOS)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    #elseif os(macOS)
    .frame(minWidth: 300, minHeight: 400)
    #endif
  }

  // MARK: Private

  private var noneOption: some View {
    Button {
      selectedListing = nil
      onDismiss()
    } label: {
      HStack {
        Text("None")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)
        Spacer()
        if selectedListing == nil {
          Image(systemName: "checkmark")
            .foregroundStyle(DS.Colors.accent)
        }
      }
      .padding(.vertical, DS.Spacing.xs)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(selectedListing == nil ? DS.Colors.accent.opacity(0.1) : Color.clear)
    .accessibilityLabel("None")
    .accessibilityAddTraits(selectedListing == nil ? .isSelected : [])
  }

  private func listingRow(_ listing: Listing) -> some View {
    let isSelected = selectedListing?.id == listing.id

    return Button {
      selectedListing = listing
      onDismiss()
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
          Text(listing.address.titleCased())
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.Text.primary)
            .lineLimit(1)
          if !listing.city.isEmpty {
            Text(listing.city.titleCased())
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.Text.secondary)
          }
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .foregroundStyle(DS.Colors.accent)
        }
      }
      .padding(.vertical, DS.Spacing.xs)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(isSelected ? DS.Colors.accent.opacity(0.1) : Color.clear)
    .accessibilityLabel(listing.address)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Preview

#Preview("StandardListingPickerSheet") {
  struct PreviewWrapper: View {
    @State private var selected: Listing?
    @State private var showSheet = true

    private var previewListings: [Listing] {
      [
        Listing(
          address: "123 Main Street",
          city: "Toronto",
          province: "ON",
          ownedBy: UUID()
        ),
        Listing(
          address: "456 Oak Avenue",
          city: "Vancouver",
          province: "BC",
          ownedBy: UUID()
        ),
        Listing(
          address: "789 Pine Road",
          city: "Calgary",
          province: "AB",
          ownedBy: UUID()
        )
      ]
    }

    var body: some View {
      Text("Selected: \(selected?.address ?? "None")")
        .sheet(isPresented: $showSheet) {
          StandardListingPickerSheet(
            selectedListing: $selected,
            listings: previewListings,
            onDismiss: { showSheet = false }
          )
        }
    }
  }

  return PreviewWrapper()
}
