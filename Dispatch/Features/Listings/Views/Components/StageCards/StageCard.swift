//
//  StageCard.swift
//  Dispatch
//
//  Individual stage filter card for the menu/sidebar grid.
//  Layout: Icon LEFT, Count RIGHT (same row), Label LEFT below.
//  Uses Dynamic Type for accessibility compliance.
//

import SwiftUI

/// A single stage filter card showing icon, count, and label.
///
/// Layout:
/// ```
/// ┌─────────────────────────────┐
/// │ 🔵                       12 │  <- Icon LEFT, Count RIGHT
/// │                             │
/// │ Label                       │  <- Label LEFT
/// └─────────────────────────────┘
/// ```
///
/// - Icon and count use `.title2` (Dynamic Type PRIMARY)
/// - Label uses `.footnote` (Dynamic Type SECONDARY)
/// - Card expands at larger accessibility text sizes
struct StageCard: View {

  // MARK: Internal

  let stage: ListingStage
  let count: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        // PRIMARY ROW: Icon LEFT, Count RIGHT
        HStack(alignment: .center) {
          // Icon - left aligned
          Image(systemName: stageIcon)
            .font(DS.Typography.StageCards.primarySemibold)
            .foregroundStyle(stageColor)

          Spacer()

          // Count - right aligned (hidden for Done stage)
          if !shouldHideCount {
            Text("\(count)")
              .font(DS.Typography.StageCards.primaryBold)
              .foregroundStyle(DS.Colors.Text.primary)
          }
        }

        Spacer(minLength: 0)

        // SECONDARY: Label - left aligned
        Text(stage.displayName)
          .font(DS.Typography.StageCards.secondary)
          .foregroundStyle(DS.Colors.Text.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .padding(DS.Spacing.StageCards.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(minHeight: DS.Spacing.StageCards.cardMinHeight, maxHeight: DS.Spacing.StageCards.cardMaxHeight)
      .background(stage.cardFillColor)
      .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityHint("Double tap to view \(stage.displayName) listings")
  }

  // MARK: Private

  private var stageColor: Color {
    stage.color
  }

  private var stageIcon: String {
    stage.icon
  }

  private var shouldHideCount: Bool {
    StageBadgeRule.shouldHideCount(stage: stage)
  }

  private var accessibilityLabelText: String {
    if stage == .done {
      stage.displayName
    } else if count == 1 {
      "\(stage.displayName), 1 listing"
    } else {
      "\(stage.displayName), \(count) listings"
    }
  }
}

// MARK: - Previews

#Preview("Stage Cards") {
  HStack(spacing: DS.Spacing.StageCards.gridSpacing) {
    StageCard(stage: .live, count: 12) { }
    StageCard(stage: .done, count: 45) { } // Count hidden
  }
  .padding()
}

#Preview("All Stages") {
  LazyVGrid(
    columns: [
      GridItem(.flexible(), spacing: DS.Spacing.StageCards.gridSpacing),
      GridItem(.flexible(), spacing: DS.Spacing.StageCards.gridSpacing)
    ],
    spacing: DS.Spacing.StageCards.gridSpacing
  ) {
    ForEach(ListingStage.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { stage in
      StageCard(stage: stage, count: stage == .done ? 45 : Int.random(in: 0 ... 15)) { }
    }
  }
  .padding()
}

#Preview("Zero Counts") {
  LazyVGrid(
    columns: [
      GridItem(.flexible(), spacing: DS.Spacing.StageCards.gridSpacing),
      GridItem(.flexible(), spacing: DS.Spacing.StageCards.gridSpacing)
    ],
    spacing: DS.Spacing.StageCards.gridSpacing
  ) {
    ForEach(ListingStage.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { stage in
      StageCard(stage: stage, count: 0) { }
    }
  }
  .padding()
}
