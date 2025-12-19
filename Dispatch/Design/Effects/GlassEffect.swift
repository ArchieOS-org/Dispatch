//
//  GlassEffect.swift
//  Dispatch
//
//  Design System - Glass Effect Primitives
//

import SwiftUI

extension View {
    /// Applies a circular glass effect background on iOS 26+, material fallback on earlier versions.
    /// Explicitly circular - use for round buttons only.
    @ViewBuilder
    func glassCircleBackground() -> some View {
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
