//
//  StageCardsSection.swift
//  Dispatch
//
//  Shared cross-platform wrapper for the stage cards grid.
//  Used by iPhone MenuPageView, iPad sidebar, and macOS sidebar.
//

import SwiftUI

/// Single wrapper component for stage cards grid.
/// Takes pre-computed counts (not listings) to avoid recomputation on every render.
struct StageCardsSection: View {
  let stageCounts: [ListingStage: Int]
  let onSelectStage: (ListingStage) -> Void

  var body: some View {
    StageCardsGrid(
      stageCounts: stageCounts,
      onSelectStage: onSelectStage,
    )
  }
}

// MARK: - Previews

#Preview("Stage Cards Section") {
  StageCardsSection(
    stageCounts: [
      .pending: 5,
      .workingOn: 3,
      .live: 12,
      .sold: 8,
      .reList: 2,
      .done: 45
    ],
    onSelectStage: { _ in },
  )
  .padding()
}
