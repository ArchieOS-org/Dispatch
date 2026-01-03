//
//  StageCard.swift
//  Dispatch
//
//  Individual stage filter card for the menu/sidebar grid.
//

import SwiftUI

/// A single stage filter card showing icon, label, and count badge.
struct StageCard: View {
    let stage: ListingStage
    let count: Int
    let action: () -> Void

    private var stageColor: Color {
        DS.Colors.Stage.color(for: stage)
    }

    private var stageIcon: String {
        DS.Icons.Stage.icon(for: stage)
    }

    private var shouldHideBadge: Bool {
        StageBadgeRule.shouldHide(stage: stage, count: count)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Main card content
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Icon
                    Image(systemName: stageIcon)
                        .font(.system(size: DS.Spacing.StageCards.iconSize, weight: .semibold))
                        .foregroundStyle(stageColor)

                    Spacer()

                    // Label
                    Text(stage.displayName)
                        .font(DS.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.Text.primary)
                        .lineLimit(1)
                }
                .padding(DS.Spacing.StageCards.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Count badge (hidden for done stage or zero count)
                if !shouldHideBadge {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.Text.secondary)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.trailing, DS.Spacing.sm)
                }
            }
            .frame(height: DS.Spacing.StageCards.cardHeight)
            .background(stageColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusCard, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Double tap to view \(stage.displayName) listings")
    }

    private var accessibilityLabelText: String {
        if shouldHideBadge {
            return stage.displayName
        } else {
            return "\(stage.displayName), \(count) listings"
        }
    }
}

// MARK: - Previews

#Preview("Stage Cards") {
    HStack(spacing: DS.Spacing.StageCards.gridSpacing) {
        StageCard(stage: .live, count: 12) { }
        StageCard(stage: .done, count: 45) { } // Badge hidden
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
            StageCard(stage: stage, count: stage == .done ? 45 : Int.random(in: 0...15)) { }
        }
    }
    .padding()
}
