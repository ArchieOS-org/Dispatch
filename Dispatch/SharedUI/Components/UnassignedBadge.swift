//
//  UnassignedBadge.swift
//  Dispatch
//
//  Badge shown when no users are assigned to a work item.
//

import SwiftUI

/// Gray pill badge indicating no one is assigned to a work item.
struct UnassignedBadge: View {

  var body: some View {
    Label("Unassigned", systemImage: "person.slash")
      .font(DS.Typography.caption)
      .foregroundStyle(DS.Colors.Text.tertiary)
      .padding(.horizontal, DS.Spacing.sm)
      .padding(.vertical, DS.Spacing.xs)
      .background(DS.Colors.Background.secondary, in: Capsule())
      .accessibilityLabel("No one assigned")
  }
}

#Preview("UnassignedBadge") {
  VStack(spacing: DS.Spacing.md) {
    UnassignedBadge()

    // Context: in a row
    HStack {
      Text("Some Task Title")
      Spacer()
      UnassignedBadge()
    }
    .padding()
    .background(DS.Colors.Background.card)
    .cornerRadius(DS.Spacing.radiusMedium)
  }
  .padding()
}
