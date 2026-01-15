//
//  DescriptionStatusChip.swift
//  Dispatch
//
//  Subtle status badge for displaying description workflow state.
//  Follows ListingTypePill pattern from DESIGN_SYSTEM.md.
//

import SwiftUI

// MARK: - DescriptionStatusChip

/// A subtle, pill-style badge displaying the current description status.
/// Uses semantic colors from DS.Colors and follows platform conventions.
struct DescriptionStatusChip: View {

  // MARK: Internal

  let status: DescriptionStatus

  var body: some View {
    HStack(spacing: DS.Spacing.xs) {
      Image(systemName: status.icon)
        .font(DS.Typography.captionSecondary)
      Text(status.title)
        .font(DS.Typography.captionSecondary)
        .fontWeight(.semibold)
    }
    .foregroundStyle(status.color)
    .padding(.horizontal, DS.Spacing.sm)
    .padding(.vertical, DS.Spacing.xs)
    .background(status.color.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Status: \(status.title)")
  }
}

// MARK: - Preview

#Preview("All Status States") {
  VStack(spacing: DS.Spacing.md) {
    ForEach(DescriptionStatus.allCases) { status in
      HStack {
        Text(status.title)
          .font(DS.Typography.body)
          .frame(width: 80, alignment: .leading)
        DescriptionStatusChip(status: status)
        Spacer()
      }
    }
  }
  .padding()
}

#Preview("Inline Usage") {
  HStack {
    Text("123 Main Street")
      .font(DS.Typography.headline)
    Spacer()
    DescriptionStatusChip(status: .ready)
  }
  .padding()
}
