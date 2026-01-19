//
//  GlassEffect.swift
//  DesignSystem
//
//  Design System - Glass Effect Primitives
//  Platform-adaptive glass and material effects.
//
//  WWDC25 Liquid Glass APIs:
//  - `.glassEffect(_ glass: Glass, in shape: Shape)` for Liquid Glass material
//  - `.sharedBackgroundVisibility(.hidden)` for toolbar item grouping
//  - Use with `GlassEffectContainer` for morphing between shapes
//
//  Currently using Material fallback until iOS 26/macOS 26 SDKs are stable in CI.
//

import SwiftUI

extension View {

  // MARK: Public

  /// Applies a circular glass effect background on iOS 26+, material fallback on earlier versions.
  /// Explicitly circular - use for round buttons only.
  @ViewBuilder
  public func glassCircleBackground() -> some View {
    // glassEffect is not available on all CI SDKs.
    // Use material fallback until the API exists in stable toolchains everywhere.
    glassCircleFallback()
  }

  /// Applies a glass effect background for sidebars and panels on macOS 26+.
  /// Falls back to platform-appropriate material on earlier versions.
  /// Use .regular (not .interactive) for static sidebars - less visual noise.
  @ViewBuilder
  public func glassSidebarBackground() -> some View {
    // glassEffect is not available on all CI SDKs.
    // Use platform-adaptive material fallback for now.
    #if os(macOS)
    // macOS: ultraThinMaterial is the most translucent, matching Xcode/Finder sidebar style
    background(.ultraThinMaterial)
    #else
    // iOS: thinMaterial for translucent sidebars
    background(.thinMaterial)
    #endif
  }

  /// Applies a rounded rectangle glass effect for toolbars on iOS 26+/macOS 26+.
  /// Falls back to thinMaterial on earlier versions.
  /// Use for floating toolbars that need Liquid Glass appearance.
  @ViewBuilder
  public func glassToolbarBackground() -> some View {
    // When iOS 26/macOS 26 SDKs are stable:
    // if #available(iOS 26.0, macOS 26.0, *) {
    //   self.glassEffect(.regular, in: .rect(cornerRadius: DS.Radius.large))
    // } else {
    //   glassToolbarFallback()
    // }
    glassToolbarFallback()
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

  @ViewBuilder
  private func glassToolbarFallback() -> some View {
    background {
      RoundedRectangle(cornerRadius: DS.Radius.large)
        .fill(.thinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: DS.Radius.large)
            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
  }

}
