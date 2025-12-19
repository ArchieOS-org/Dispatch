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
                    // Symbol with palette rendering
                    // Style 1 = outer circle (subtle), Style 2 = inner lines (tinted)
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: size * 0.43, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.primary.opacity(0.35), lens.tintColor)
                        .symbolEffect(.bounce.up.wholeSymbol, options: .nonRepeating, value: bounceTrigger)
                }

            // Dot indicator when filtered
            if isFiltered {
                Circle()
                    .fill(.primary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: -4, y: 4)
            }
        }
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
