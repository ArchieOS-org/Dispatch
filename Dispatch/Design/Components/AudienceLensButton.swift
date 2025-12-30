//
//  AudienceLensButton.swift
//  Dispatch
//
//  Design System - Audience lens filter button component
//

import SwiftUI

/// A glass-styled button that displays the current AudienceLens.
/// Renders a single symbol with lens-tinted inner lines.
/// Does NOT handle gestures - parent owns tap/menu behavior.
struct AudienceLensButton: View {
    // MARK: - Required

    let lens: AudienceLens

    // MARK: - Optional Configuration

    var isFiltered: Bool = false
    var size: CGFloat = 56

    // MARK: - Animation Trigger (external control)

    var bounceTrigger: Int = 0

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Glass container
            Circle()
                .fill(.clear)
                .frame(width: size, height: size)
                .glassCircleBackground()
                .overlay {
                    // Symbol with dynamic rendering based on lens type
                    // .all -> Palette (Ring + Tinted Lines)
                    // .role -> Hierarchical (Clean letter in circle)
                    if lens == .all {
                         Image(systemName: lens.icon)
                            .font(.system(size: size * 0.43, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary.opacity(0.35), lens.tintColor)
                            .symbolEffect(.bounce.up.wholeSymbol, options: .nonRepeating, value: bounceTrigger)
                    } else {
                        Image(systemName: lens.icon)
                            .font(.system(size: size * 0.43, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(lens.tintColor)
                            .symbolEffect(.bounce.up.wholeSymbol, options: .nonRepeating, value: bounceTrigger)
                    }
                }

            // Dot indicator when filtered
            if isFiltered {
                Circle()
                    .fill(.primary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: -4, y: 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("AudienceFilterButton")
        // Label for VoiceOver (User Facing)
        .accessibilityLabel("Audience Filter: \(lens.label)")
        // Value for Tests (Stable ID)
        .accessibilityValue(lens.rawValue)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("AudienceLensButton - All") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        AudienceLensButton(lens: .all)
    }
}

#Preview("AudienceLensButton - Admin") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        AudienceLensButton(lens: .admin, isFiltered: true)
    }
}

#Preview("AudienceLensButton - Marketing") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        AudienceLensButton(lens: .marketing, isFiltered: true)
    }
}

#Preview("AudienceLensButton - All States") {
    ZStack {
        DS.Colors.Background.grouped
            .ignoresSafeArea()

        VStack(spacing: DS.Spacing.xl) {
            ForEach(AudienceLens.allCases, id: \.self) { lens in
                HStack(spacing: DS.Spacing.lg) {
                    AudienceLensButton(lens: lens)
                    AudienceLensButton(lens: lens, isFiltered: true)
                    Text(lens.label)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.Text.primary)
                }
            }
        }
    }
}
