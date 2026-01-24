//
//  GlassEffect.swift
//  DesignSystem
//
//  Design System - Glass Effect Primitives
//  Platform-adaptive glass and material effects.
//
//  WWDC25 Liquid Glass APIs:
//  - `.glassEffect(_ glass: Glass, in shape: Shape)` for Liquid Glass material
//  - `.buttonStyle(.glass)` for native glass button styling
//  - `.sharedBackgroundVisibility(.hidden)` for toolbar item grouping
//  - Use with `GlassEffectContainer` for morphing between shapes
//
//  iOS 26 Migration Strategy:
//  - Use `.buttonStyle(.glass)` for buttons in toolbar/accessory placements
//  - Use `.glassBackgroundEffect()` for custom floating views
//  - Fall back to Material for pre-iOS 26 compatibility
//

import SwiftUI

// MARK: - iOS 26 Glass Button Style Extension

extension View {

  /// Applies native iOS 26 glass button style with material fallback for earlier versions.
  /// Use this for buttons that should have Liquid Glass appearance on iOS 26+.
  ///
  /// iOS 26+: Will use native `.buttonStyle(.glass)` for true Liquid Glass (when SDK available)
  /// Pre-iOS 26: Button retains its existing style (caller provides fallback)
  ///
  /// - Note: This modifier only applies glass styling on iOS 26+.
  ///   For pre-iOS 26 fallback, wrap the button content in a material background.
  ///
  /// Enable native glass when iOS 26 SDK is available in CI by uncommenting:
  /// ```swift
  /// if #available(iOS 26.0, macOS 26.0, *) {
  ///   self.buttonStyle(.glass)
  /// } else { self }
  /// ```
  @ViewBuilder
  public func glassButtonStyleIfAvailable() -> some View {
    // iOS 26 SDK not yet available in CI - using fallback path
    // When Xcode 18 with iOS 26 SDK ships, enable native glass
    self
  }

  /// Applies native iOS 26 prominent glass button style with material fallback.
  /// Use for buttons that need a more prominent glass appearance.
  ///
  /// iOS 26+: Will use native `.buttonStyle(.glassProminent)` (when SDK available)
  /// Pre-iOS 26: Button retains its existing style (caller provides fallback)
  ///
  /// Enable native glass when iOS 26 SDK is available in CI by uncommenting:
  /// ```swift
  /// if #available(iOS 26.0, macOS 26.0, *) {
  ///   self.buttonStyle(.glassProminent)
  /// } else { self }
  /// ```
  @ViewBuilder
  public func prominentGlassButtonStyleIfAvailable() -> some View {
    // iOS 26 SDK not yet available in CI - using fallback path
    self
  }

}

extension View {

  // MARK: Public

  /// Applies a circular glass effect background on iOS 26+, material fallback on earlier versions.
  /// Explicitly circular - use for round buttons only.
  ///
  /// iOS 26+: Will use native `glassBackgroundEffect(in: Circle())` for Liquid Glass (when SDK available)
  /// Pre-iOS 26: Uses `ultraThinMaterial` with stroke border and shadow
  ///
  /// Enable native glass when iOS 26 SDK is available in CI by uncommenting:
  /// ```swift
  /// if #available(iOS 26.0, macOS 26.0, *) {
  ///   self.glassBackgroundEffect(in: Circle(), displayMode: .always)
  /// } else { glassCircleFallback() }
  /// ```
  @ViewBuilder
  public func glassCircleBackground() -> some View {
    // iOS 26 SDK not yet available in CI - using fallback path
    // When Xcode 18 with iOS 26 SDK ships, enable native glass
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
    // macOS: thinMaterial matches toolbar material for seamless integration under unified toolbar.
    // Using same material as glassFullWidthToolbarBackground() prevents visible color line at junction.
    background(.thinMaterial)
    #else
    // iOS: thinMaterial for translucent sidebars
    background(.thinMaterial)
    #endif
  }

  /// Applies a capsule glass effect background on iOS 26+, material fallback on earlier versions.
  /// Use for pill-shaped buttons and menu items.
  ///
  /// iOS 26+: Will use native `glassBackgroundEffect(in: Capsule())` for Liquid Glass (when SDK available)
  /// Pre-iOS 26: Uses `regularMaterial` with shadow
  ///
  /// Enable native glass when iOS 26 SDK is available in CI by uncommenting:
  /// ```swift
  /// if #available(iOS 26.0, macOS 26.0, *) {
  ///   self.glassBackgroundEffect(in: Capsule(), displayMode: .always)
  /// } else { glassCapsuleFallback() }
  /// ```
  @ViewBuilder
  public func glassCapsuleBackground() -> some View {
    // iOS 26 SDK not yet available in CI - using fallback path
    glassCapsuleFallback()
  }

  /// Applies a rounded rectangle glass effect for toolbars on iOS 26+/macOS 26+.
  /// Falls back to thinMaterial on earlier versions.
  /// Use for floating toolbars that need Liquid Glass appearance.
  ///
  /// Enable native glass when iOS 26 SDK is available in CI by uncommenting:
  /// ```swift
  /// if #available(iOS 26.0, macOS 26.0, *) {
  ///   self.glassBackgroundEffect(in: RoundedRectangle(cornerRadius: DS.Radius.large), displayMode: .always)
  /// } else { glassToolbarFallback() }
  /// ```
  @ViewBuilder
  public func glassToolbarBackground() -> some View {
    // iOS 26 SDK not yet available in CI - using fallback path
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
  private func glassCapsuleFallback() -> some View {
    background(.regularMaterial)
      .clipShape(Capsule())
      .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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

// MARK: - Shape Glass Effects

extension Shape {

  /// Applies a floating glass panel effect for sidebars on macOS.
  /// Uses ultraThinMaterial for maximum translucency with shadow and stroke border.
  /// On iOS, falls back to thinMaterial without floating panel styling.
  /// - Note: Call on a Shape (e.g., `RoundedRectangle(cornerRadius: 16).glassFloatingSidebarBackground()`)
  @ViewBuilder
  public func glassFloatingSidebarBackground() -> some View {
    #if os(macOS)
    fill(.ultraThinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: DS.Radius.floatingPanel)
          .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
      }
      .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    #else
    fill(.thinMaterial)
    #endif
  }

  /// Applies a floating glass panel effect for bottom toolbars on macOS.
  /// Uses thinMaterial with rounded corners, shadow, and stroke border.
  /// - Note: Call on a Shape (e.g., `RoundedRectangle(cornerRadius: 16).glassFloatingToolbarBackground()`)
  @ViewBuilder
  public func glassFloatingToolbarBackground() -> some View {
    #if os(macOS)
    fill(.thinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: DS.Radius.floatingPanel)
          .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
      }
      .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: -2)
    #else
    fill(.regularMaterial)
    #endif
  }

}

// MARK: - View Glass Effects (Full-Width)

extension View {

  /// Applies a full-width glass toolbar background for macOS.
  /// No rounded corners - spans the full window width.
  /// Uses thin material with a top stroke for visual separation.
  @ViewBuilder
  public func glassFullWidthToolbarBackground() -> some View {
    #if os(macOS)
    background(.thinMaterial)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(.white.opacity(0.15))
          .frame(height: 0.5)
      }
    #else
    background(.regularMaterial)
    #endif
  }

}
