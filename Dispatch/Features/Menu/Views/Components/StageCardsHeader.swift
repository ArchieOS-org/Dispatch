//
//  StageCardsHeader.swift
//  Dispatch
//
//  Reusable stage cards header component.
//  Used by:
//  - iPhone: MenuPageView
//  - iPad sidebar: tabViewSidebarHeader
//  - iPad tab bar mode: ListingListView (collapsed DisclosureGroup)
//  - macOS: Sidebar above SidebarTabList
//

import SwiftUI

/// Standalone header wrapping StageCardsSection with consistent padding.
/// This is the canonical component for stage cards across all platforms.
struct StageCardsHeader: View {
  let stageCounts: [ListingStage: Int]
  let onSelectStage: (ListingStage) -> Void

  var body: some View {
    VStack(spacing: DS.Spacing.md) {
      StageCardsSection(
        stageCounts: stageCounts,
        onSelectStage: onSelectStage
      )
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.sm)
  }
}

// MARK: - Preview

#Preview("Stage Cards Header") {
  StageCardsHeader(
    stageCounts: [
      .pending: 5,
      .workingOn: 3,
      .live: 12,
      .sold: 8,
      .reList: 2,
      .done: 45
    ],
    onSelectStage: { stage in
      print("Selected: \(stage)")
    }
  )
}
