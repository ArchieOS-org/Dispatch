//
//  MLSFieldsSection.swift
//  Dispatch
//
//  Display all MLS fields with copy-to-clipboard functionality.
//  Groups fields by category with collapsible sections.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - MLSFieldsSection

/// Section displaying all MLS fields with copy buttons and inline editing.
/// Fields are grouped by category with collapsible disclosure groups.
struct MLSFieldsSection: View {

  // MARK: Internal

  /// Binding to the MLS fields
  @Binding var fields: MLSFields

  /// Original generated fields for reset functionality
  let originalFields: MLSFields

  /// Session ID for training data logging
  var sessionId: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header with Copy All button
      headerSection

      // Field groups
      fieldGroups
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: Private

  @State private var expandedSections: Set<FieldGroup> = [.marketing, .descriptions]
  @State private var showCopyAllSuccess = false

  private let trainingService = MockTrainingDataService()

  @ViewBuilder
  private var headerSection: some View {
    HStack {
      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text("MLS Fields")
          .font(DS.Typography.headline)
          .foregroundStyle(DS.Colors.Text.primary)

        Text("Tap any field to edit, or copy individually")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.Text.secondary)
      }

      Spacer()

      // Copy All button
      Button {
        copyAllFields()
      } label: {
        HStack(spacing: DS.Spacing.xs) {
          Image(systemName: showCopyAllSuccess ? "checkmark" : "doc.on.doc.fill")
            .font(.system(size: 12))
          Text(showCopyAllSuccess ? "Copied!" : "Copy All")
            .font(DS.Typography.caption)
            .fontWeight(.medium)
        }
        .foregroundStyle(showCopyAllSuccess ? DS.Colors.success : DS.Colors.accent)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
          (showCopyAllSuccess ? DS.Colors.success : DS.Colors.accent).opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Copy all MLS fields")
      .accessibilityHint("Double tap to copy all fields to clipboard")
    }
  }

  @ViewBuilder
  private var fieldGroups: some View {
    VStack(spacing: DS.Spacing.sm) {
      // Marketing (usually most important, default expanded)
      fieldGroupSection(.marketing)

      // Descriptions
      fieldGroupSection(.descriptions)

      // Property Details
      fieldGroupSection(.propertyDetails)

      // Features
      fieldGroupSection(.features)
    }
  }

  // MARK: - Property Details Fields

  @ViewBuilder
  private var propertyDetailsFields: some View {
    MLSFieldRow(
      label: "Property Type",
      value: $fields.propertyType,
      originalValue: originalFields.propertyType,
      onCopy: { logFieldCopy("propertyType") }
    )
    MLSFieldRow(
      label: "Year Built",
      value: $fields.yearBuilt,
      originalValue: originalFields.yearBuilt,
      onCopy: { logFieldCopy("yearBuilt") }
    )
    MLSFieldRow(
      label: "Square Footage",
      value: $fields.squareFootage,
      originalValue: originalFields.squareFootage,
      onCopy: { logFieldCopy("squareFootage") }
    )
    MLSFieldRow(
      label: "Lot Size",
      value: $fields.lotSize,
      originalValue: originalFields.lotSize,
      onCopy: { logFieldCopy("lotSize") }
    )
    MLSFieldRow(
      label: "Bedrooms",
      value: $fields.bedrooms,
      originalValue: originalFields.bedrooms,
      onCopy: { logFieldCopy("bedrooms") }
    )
    MLSFieldRow(
      label: "Bathrooms",
      value: $fields.bathrooms,
      originalValue: originalFields.bathrooms,
      onCopy: { logFieldCopy("bathrooms") }
    )
    MLSFieldRow(
      label: "Stories",
      value: $fields.stories,
      originalValue: originalFields.stories,
      onCopy: { logFieldCopy("stories") }
    )
    MLSFieldRow(
      label: "Parking Spaces",
      value: $fields.parkingSpaces,
      originalValue: originalFields.parkingSpaces,
      onCopy: { logFieldCopy("parkingSpaces") }
    )
    MLSFieldRow(
      label: "Garage Type",
      value: $fields.garageType,
      originalValue: originalFields.garageType,
      onCopy: { logFieldCopy("garageType") }
    )
  }

  // MARK: - Features Fields

  @ViewBuilder
  private var featuresFields: some View {
    MLSFieldRow(
      label: "Heating/Cooling",
      value: $fields.heatingCooling,
      originalValue: originalFields.heatingCooling,
      onCopy: { logFieldCopy("heatingCooling") }
    )
    MLSFieldRow(
      label: "Flooring",
      value: $fields.flooring,
      originalValue: originalFields.flooring,
      onCopy: { logFieldCopy("flooring") }
    )
    MLSFieldRow(
      label: "Appliances",
      value: $fields.appliances,
      originalValue: originalFields.appliances,
      onCopy: { logFieldCopy("appliances") }
    )
    MLSFieldRow(
      label: "Exterior Features",
      value: $fields.exteriorFeatures,
      originalValue: originalFields.exteriorFeatures,
      onCopy: { logFieldCopy("exteriorFeatures") }
    )
    MLSFieldRow(
      label: "Interior Features",
      value: $fields.interiorFeatures,
      originalValue: originalFields.interiorFeatures,
      onCopy: { logFieldCopy("interiorFeatures") }
    )
    MLSFieldRow(
      label: "Community Features",
      value: $fields.communityFeatures,
      originalValue: originalFields.communityFeatures,
      onCopy: { logFieldCopy("communityFeatures") }
    )
  }

  // MARK: - Descriptions Fields

  @ViewBuilder
  private var descriptionsFields: some View {
    MLSFieldRow(
      label: "Public Remarks",
      value: $fields.publicRemarks,
      originalValue: originalFields.publicRemarks,
      isMultiline: true,
      onCopy: { logFieldCopy("publicRemarks") }
    )
    MLSFieldRow(
      label: "Private Remarks",
      value: $fields.privateRemarks,
      originalValue: originalFields.privateRemarks,
      isMultiline: true,
      onCopy: { logFieldCopy("privateRemarks") }
    )
    MLSFieldRow(
      label: "Directions",
      value: $fields.directions,
      originalValue: originalFields.directions,
      isMultiline: true,
      onCopy: { logFieldCopy("directions") }
    )
  }

  // MARK: - Marketing Fields

  @ViewBuilder
  private var marketingFields: some View {
    MLSFieldRow(
      label: "Headline",
      value: $fields.headline,
      originalValue: originalFields.headline,
      onCopy: { logFieldCopy("headline") }
    )
    MLSFieldRow(
      label: "Tagline",
      value: $fields.tagline,
      originalValue: originalFields.tagline,
      onCopy: { logFieldCopy("tagline") }
    )
  }

  @ViewBuilder
  private func fieldGroupSection(_ group: FieldGroup) -> some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { expandedSections.contains(group) },
        set: { isExpanded in
          if isExpanded {
            expandedSections.insert(group)
          } else {
            expandedSections.remove(group)
          }
        }
      )
    ) {
      fieldGroupContent(group)
        .padding(.top, DS.Spacing.sm)
    } label: {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: group.icon)
          .font(.system(size: 14))
          .foregroundStyle(DS.Colors.Text.secondary)
          .frame(width: 20)

        Text(group.title)
          .font(DS.Typography.callout)
          .fontWeight(.medium)
          .foregroundStyle(DS.Colors.Text.primary)

        Spacer()

        // Field count badge
        Text("\(fieldCount(for: group))")
          .font(DS.Typography.captionSecondary)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .padding(.horizontal, DS.Spacing.xs)
          .padding(.vertical, 2)
          .background(DS.Colors.Background.secondary)
          .clipShape(Capsule())
      }
    }
    .tint(DS.Colors.Text.secondary)
  }

  @ViewBuilder
  private func fieldGroupContent(_ group: FieldGroup) -> some View {
    VStack(spacing: DS.Spacing.sm) {
      switch group {
      case .propertyDetails:
        propertyDetailsFields

      case .features:
        featuresFields

      case .descriptions:
        descriptionsFields

      case .marketing:
        marketingFields
      }
    }
  }

  // MARK: - Helpers

  private func fieldCount(for group: FieldGroup) -> Int {
    switch group {
    case .propertyDetails: 9
    case .features: 6
    case .descriptions: 3
    case .marketing: 2
    }
  }

  private func copyAllFields() {
    let formattedText = fields.formattedForCopy()

    #if canImport(UIKit)
    UIPasteboard.general.string = formattedText
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)

    // Announce for VoiceOver
    UIAccessibility.post(notification: .announcement, argument: "All fields copied to clipboard")
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(formattedText, forType: .string)

    // Announce for VoiceOver on macOS
    NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested)
    #endif

    withAnimation(.easeInOut(duration: 0.2)) {
      showCopyAllSuccess = true
    }

    // Reset after delay using proper async pattern
    Task { @MainActor in
      await CopyFeedback.resetFeedbackFlag($showCopyAllSuccess, after: CopyFeedback.longDelay)
    }
  }

  private func logFieldCopy(_ fieldName: String) {
    // PHASE 3: Log field copy for analytics
    // swiftlint:disable:next no_direct_standard_out_logs
    print("[MLS] Field copied: \(fieldName)")
  }
}

// MARK: - FieldGroup

/// Groups of MLS fields for organization.
private enum FieldGroup: String, CaseIterable {
  case propertyDetails
  case features
  case descriptions
  case marketing

  // MARK: Internal

  var title: String {
    switch self {
    case .propertyDetails: "Property Details"
    case .features: "Features"
    case .descriptions: "Descriptions"
    case .marketing: "Marketing"
    }
  }

  var icon: String {
    switch self {
    case .propertyDetails: "house"
    case .features: "star"
    case .descriptions: "doc.text"
    case .marketing: "megaphone"
    }
  }
}

// MARK: - Preview

#Preview("MLS Fields Section") {
  struct PreviewWrapper: View {
    @State private var fields = MLSFields.mockProfessional

    var body: some View {
      ScrollView {
        MLSFieldsSection(
          fields: $fields,
          originalFields: .mockProfessional
        )
        .padding()
      }
      .background(DS.Colors.Background.grouped)
    }
  }

  return PreviewWrapper()
}
