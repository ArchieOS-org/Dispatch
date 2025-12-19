//
//  GlassButton.swift
//  Dispatch
//
//  A floating button with liquid glass styling for iOS 26+ with material fallback
//

import SwiftUI

/// A circular button with liquid glass styling.
/// Uses `glassEffect` on iOS 26+, falls back to `ultraThinMaterial` on earlier versions.
struct GlassButton: View {
    let icon: String
    let action: () -> Void
    var isFiltered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Glass background on container, not icon
                Circle()
                    .fill(.clear)
                    .frame(width: 56, height: 56)
                    .glassEffectBackground()
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                // Subtle dot indicator when filtered (white, not accent - too loud)
                if isFiltered {
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Effect Background

extension View {
    /// Applies a glass effect background on iOS 26+, material fallback on earlier versions.
    @ViewBuilder
    func glassEffectBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Previews

#Preview("Glass Button - Default") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        GlassButton(icon: "eye", action: {})
    }
}

#Preview("Glass Button - Filtered") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        GlassButton(icon: "person.badge.shield.checkmark", action: {}, isFiltered: true)
    }
}
