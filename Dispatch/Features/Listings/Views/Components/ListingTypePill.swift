//
//  ListingTypePill.swift
//  Dispatch
//
//  Pill component for displaying listing type (Sale, Lease, etc.)
//  Created by Claude on 2025-12-06.
//

import SwiftUI

struct ListingTypePill: View {

  // MARK: Lifecycle

  /// Creates a pill using only the listing type enum (uses default colors).
  init(type: ListingType) {
    self.type = type
    definition = nil
  }

  /// Creates a pill using a listing type definition (uses custom color if set).
  init(type: ListingType, definition: ListingTypeDefinition?) {
    self.type = type
    self.definition = definition
  }

  // MARK: Internal

  let type: ListingType

  var body: some View {
    Text(title)
      .font(.system(size: fontSize, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.12))
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Listing type: \(title)")
  }

  // MARK: Private

  /// Optional definition for custom color support
  private let definition: ListingTypeDefinition?

  /// Scaled font size for Dynamic Type support (base: 10pt)
  @ScaledMetric(relativeTo: .caption2)
  private var fontSize: CGFloat = 10

  /// Returns custom name from definition if available, otherwise falls back to hardcoded defaults.
  private var title: String {
    // Use custom name from definition if available
    if let definition {
      return definition.name
    }

    // Fall back to hardcoded defaults per listing type
    return switch type {
    case .sale: "Sale"
    case .lease: "Lease"
    case .preListing: "Pre-List"
    case .rental: "Rental"
    case .other: "Other"
    }
  }

  /// Returns custom color from definition if available, otherwise falls back to hardcoded defaults.
  private var color: Color {
    // Use custom color from definition if available
    if let definition, let hex = definition.colorHex, let customColor = Color(hex: hex) {
      return customColor
    }

    // Fall back to hardcoded defaults per listing type
    return switch type {
    case .sale: DS.Colors.success // Green
    case .lease: Color.purple // Purple
    case .preListing: DS.Colors.info // Blue
    case .rental: DS.Colors.warning // Orange
    case .other: DS.Colors.Text.tertiary // Gray
    }
  }
}

#Preview {
  HStack {
    ListingTypePill(type: .sale)
    ListingTypePill(type: .lease)
    ListingTypePill(type: .preListing)
    ListingTypePill(type: .rental)
    ListingTypePill(type: .other)
  }
  .padding()
}
