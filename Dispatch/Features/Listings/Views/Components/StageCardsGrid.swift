//
//  StageCardsGrid.swift
//  Dispatch
//
//  2x3 grid container for stage filter cards.
//

import SwiftUI

/// A 2x3 grid of stage filter cards.
struct StageCardsGrid: View {

  // MARK: Internal

  let stageCounts: [ListingStage: Int]
  let onSelectStage: (ListingStage) -> Void

  var body: some View {
    LazyVGrid(columns: columns, spacing: DS.Spacing.StageCards.gridSpacing) {
      ForEach(ListingStage.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { stage in
        StageCard(
          stage: stage,
          count: stageCounts[stage, default: 0],
          action: { onSelectStage(stage) },
        )
      }
    }
  }

  // MARK: Private

  private let columns = [
    GridItem(.flexible(), spacing: DS.Spacing.StageCards.gridSpacing),
    GridItem(.flexible(), spacing: DS.Spacing.StageCards.gridSpacing)
  ]

}

// MARK: - Previews

#Preview("Stage Cards Grid") {
  StageCardsGrid(
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

#Preview("Empty Counts") {
  StageCardsGrid(
    stageCounts: [:],
    onSelectStage: { _ in },
  )
  .padding()
}
