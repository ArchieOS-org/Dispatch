//
//  ListingPickerRow.swift
//  Dispatch
//
//  Row component for selecting a listing in the description generator.
//  Displays address, type, and selection state.
//

import SwiftData
import SwiftUI

// MARK: - ListingPickerRow

/// A selectable row for displaying a listing in the picker.
/// Shows address, listing type, and city with clear selection feedback.
struct ListingPickerRow: View {

  let listing: Listing
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DS.Spacing.md) {
        // Selection indicator
        ZStack {
          Circle()
            .strokeBorder(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: 2)
            .frame(width: DS.Spacing.xxl, height: DS.Spacing.xxl)

          if isSelected {
            Circle()
              .fill(DS.Colors.accent)
              .frame(width: DS.Spacing.md, height: DS.Spacing.md)
          }
        }

        // Listing info
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
          Text(listing.address)
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.Text.primary)
            .lineLimit(1)

          HStack(spacing: DS.Spacing.xs) {
            if !listing.city.isEmpty {
              Text(listing.city)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.Text.secondary)
            }

            ListingTypePill(type: listing.listingType)
          }
        }

        Spacer()

        // Chevron
        Image(systemName: DS.Icons.Navigation.forward)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.tertiary)
      }
      .padding(.vertical, DS.Spacing.sm)
      .padding(.horizontal, DS.Spacing.md)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(minHeight: DS.Spacing.minTouchTarget)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(listing.address), \(listing.city), \(listing.listingType.displayName)")
    .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Preview

#Preview("Listing Picker Row") {
  PreviewShell { context in
    let listings = (try? context.fetch(FetchDescriptor<Listing>())) ?? []

    VStack(spacing: 0) {
      if let first = listings.first {
        ListingPickerRow(listing: first, isSelected: true) { }
        Divider()
      }
      if listings.count > 1 {
        ListingPickerRow(listing: listings[1], isSelected: false) { }
      }
    }
    .background(DS.Colors.Background.grouped)
  }
}
