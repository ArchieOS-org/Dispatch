//
//  OutputCard.swift
//  Dispatch
//
//  Card displaying a single AI-generated output for A/B comparison.
//  Shows version label, headline, tagline, and description preview.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - OutputCard

/// Card component displaying a single generated output version.
/// Supports selection state with visual feedback.
struct OutputCard: View {

  // MARK: Internal

  /// The generated output to display
  let output: GeneratedOutput

  /// Callback when card is tapped to select
  var onSelect: (() -> Void)?

  /// Whether to show the full description or truncated preview
  var isExpanded: Bool = false

  var body: some View {
    Button {
      onSelect?()
      // Announce selection for VoiceOver
      #if canImport(UIKit)
      if !output.isSelected {
        UIAccessibility.post(
          notification: .announcement,
          argument: "\(output.version.rawValue) selected"
        )
      }
      #endif
    } label: {
      cardContent
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(output.isSelected ? "Currently selected" : "Double tap to select this version")
    .accessibilityAddTraits(output.isSelected ? .isSelected : [])
  }

  // MARK: Private

  @ViewBuilder
  private var cardContent: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Header with version badge
      headerSection

      Divider()

      // Content preview
      contentSection

      // Selection indicator
      if output.isSelected {
        selectionIndicator
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(output.isSelected ? DS.Colors.accent.opacity(0.06) : DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
    .overlay(
      RoundedRectangle(cornerRadius: DS.Spacing.radiusCard)
        .stroke(
          output.isSelected ? DS.Colors.accent : DS.Colors.border,
          lineWidth: output.isSelected ? 2 : 1
        )
    )
    .animation(.easeInOut(duration: 0.2), value: output.isSelected)
  }

  @ViewBuilder
  private var headerSection: some View {
    HStack(alignment: .top) {
      // Version badge
      Text(output.version.shortLabel)
        .font(DS.Typography.headline)
        .fontWeight(.bold)
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(output.isSelected ? DS.Colors.accent : DS.Colors.Text.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))

      Spacer()

      // Tone description
      Text(output.version.toneDescription)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)
    }
  }

  @ViewBuilder
  private var contentSection: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      // Headline
      Text(output.mlsFields.headline)
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)
        .lineLimit(isExpanded ? nil : 2)

      // Tagline
      if !output.mlsFields.tagline.isEmpty {
        Text(output.mlsFields.tagline)
          .font(DS.Typography.callout)
          .foregroundStyle(DS.Colors.Text.secondary)
          .italic()
          .lineLimit(isExpanded ? nil : 1)
      }

      // Description preview
      Text(output.mlsFields.publicRemarks)
        .font(DS.Typography.body)
        .foregroundStyle(DS.Colors.Text.primary)
        .lineLimit(isExpanded ? nil : 4)
    }
  }

  @ViewBuilder
  private var selectionIndicator: some View {
    HStack(spacing: DS.Spacing.xs) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 14))
      Text("Selected")
        .font(DS.Typography.captionSecondary)
        .fontWeight(.semibold)
    }
    .foregroundStyle(DS.Colors.accent)
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.top, DS.Spacing.xs)
  }

  private var accessibilityLabel: String {
    var label = "\(output.version.rawValue), \(output.version.toneDescription). "
    label += "Headline: \(output.mlsFields.headline). "
    if !output.mlsFields.tagline.isEmpty {
      label += "Tagline: \(output.mlsFields.tagline). "
    }
    return label
  }
}

// MARK: - Preview

#Preview("Output Card - Unselected") {
  let output = GeneratedOutput(
    version: .a,
    mlsFields: MLSFields.mockProfessional,
    isSelected: false
  )

  return OutputCard(output: output)
    .padding()
}

#Preview("Output Card - Selected") {
  let output = GeneratedOutput(
    version: .b,
    mlsFields: MLSFields.mockWarm,
    isSelected: true
  )

  return OutputCard(output: output)
    .padding()
}

// MARK: - MLSFields Mock Extensions

extension MLSFields {
  /// Mock professional tone MLS fields for previews
  static var mockProfessional: MLSFields {
    var fields = MLSFields()
    fields.propertyType = "Single Family"
    fields.yearBuilt = "2015"
    fields.squareFootage = "2,450"
    fields.lotSize = "0.25 acres"
    fields.bedrooms = "4"
    fields.bathrooms = "2.5"
    fields.stories = "2"
    fields.parkingSpaces = "2"
    fields.garageType = "Attached 2-Car"
    fields.heatingCooling = "Central Air, Forced Air"
    fields.flooring = "Hardwood, Tile, Carpet"
    fields.appliances = "Stainless Steel Refrigerator, Dishwasher, Microwave, Gas Range"
    fields.exteriorFeatures = "Covered Patio, Fenced Yard, Sprinkler System"
    fields.interiorFeatures = "Fireplace, High Ceilings, Walk-in Closets"
    fields.communityFeatures = "Pool, Tennis Courts, Playground"
    fields.headline = "Exceptional Residence in Prime Location"
    fields.tagline = "Sophisticated living meets modern convenience"
    fields.publicRemarks = """
      This meticulously maintained 4-bedroom, 2.5-bathroom residence offers 2,450 square feet \
      of refined living space. Built in 2015, this two-story home features premium finishes throughout.
      """
    fields.privateRemarks = "Seller motivated. Pre-approved buyers preferred."
    fields.directions = "From Main St, turn east on Oak Ave, property on right."
    return fields
  }

  /// Mock warm tone MLS fields for previews
  static var mockWarm: MLSFields {
    var fields = mockProfessional
    fields.headline = "Welcome Home to Your Dream Property"
    fields.tagline = "Where memories are made and families thrive"
    fields.publicRemarks = """
      Imagine coming home to this beautiful 4-bedroom, 2.5-bathroom family home! \
      With 2,450 square feet of warm, inviting living space, there's room for everyone.
      """
    fields.privateRemarks = "Sellers are relocating and flexible on timing."
    fields.directions = "Head east on Main St, turn right onto Oak Ave. Look for the welcoming front porch!"
    return fields
  }
}
