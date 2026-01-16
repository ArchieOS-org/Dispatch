//
//  ReportToggleSection.swift
//  Dispatch
//
//  Minimal toggle section for enabling property reports during generation.
//  Uses plain SwiftUI Toggles for native feel.
//

import SwiftUI

// MARK: - ReportToggleSection

/// Section containing toggles for enabling GEOWarehouse and MPAC reports.
/// Designed to be minimal and unobtrusive - plain toggles, secondary styling.
struct ReportToggleSection: View {

  // MARK: Internal

  @Binding var enableGeoWarehouse: Bool
  @Binding var enableMPAC: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.md) {
      // Section header
      Text("Property Reports")
        .font(DS.Typography.headline)
        .foregroundStyle(DS.Colors.Text.primary)

      Text("Include additional data in generation")
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.Text.secondary)

      // Toggles
      VStack(spacing: DS.Spacing.sm) {
        reportToggle(
          title: ReportType.geoWarehouse.displayName,
          icon: ReportType.geoWarehouse.icon,
          isOn: $enableGeoWarehouse
        )

        reportToggle(
          title: ReportType.mpac.displayName,
          icon: ReportType.mpac.icon,
          isOn: $enableMPAC
        )
      }
    }
    .padding(DS.Spacing.cardPadding)
    .background(DS.Colors.Background.card)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard))
  }

  // MARK: Private

  @ViewBuilder
  private func reportToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .regular))
          .foregroundStyle(DS.Colors.Text.secondary)
          .frame(width: DS.Spacing.avatarSmall, alignment: .center)
          .accessibilityHidden(true)

        Text(title)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Colors.Text.primary)
      }
    }
    .toggleStyle(.switch)
    .accessibilityLabel("\(title) report")
    .accessibilityHint(isOn.wrappedValue ? "Enabled. Double tap to disable." : "Disabled. Double tap to enable.")
  }
}

// MARK: - Preview

#Preview("Report Toggles - Off") {
  ReportToggleSection(
    enableGeoWarehouse: .constant(false),
    enableMPAC: .constant(false)
  )
  .padding()
  .background(DS.Colors.Background.grouped)
}

#Preview("Report Toggles - On") {
  ReportToggleSection(
    enableGeoWarehouse: .constant(true),
    enableMPAC: .constant(true)
  )
  .padding()
  .background(DS.Colors.Background.grouped)
}
