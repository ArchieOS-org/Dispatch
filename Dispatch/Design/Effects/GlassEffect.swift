//
//  GlassEffect.swift
//  Dispatch
//
//  Design System - Glass Effect Primitives
//

import SwiftUI

extension View {

  // MARK: Internal

  /// Applies a circular glass effect background on iOS 26+, material fallback on earlier versions.
  /// Explicitly circular - use for round buttons only.
  @ViewBuilder
  func glassCircleBackground() -> some View {
    // glassEffect is not available on all CI SDKs.
    // Use material fallback until the API exists in stable toolchains everywhere.
    glassCircleFallback()
  }

  /// Applies a glass effect background for sidebars and panels on macOS 26+.
  /// Falls back to regularMaterial on earlier versions.
  /// Use .regular (not .interactive) for static sidebars - less visual noise.
  @ViewBuilder
  func glassSidebarBackground() -> some View {
    // glassEffect is not available on all CI SDKs.
    // Use material fallback for now.
    background(.regularMaterial)
  }

  // MARK: Private

  @ViewBuilder
  private func glassCircleFallback() -> some View {
    background(.ultraThinMaterial)
      .clipShape(Circle())
      .overlay {
        Circle()
          .strokeBorder(.white.opacity(0.2), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
  }

}
