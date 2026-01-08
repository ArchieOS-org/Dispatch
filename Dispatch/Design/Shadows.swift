//
//  Shadows.swift
//  Dispatch
//
//  Design Tokens - Shadow Styles & Gradients
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI

// MARK: - DS.Shadows

extension DS {
  /// Shadow tokens for consistent elevation and depth across the app.
  enum Shadows {
    /// Reusable shadow style configuration
    struct Style {
      /// Creates a shadow style
      init(color: Color = .black.opacity(0.1), radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
      }

      let color: Color
      let radius: CGFloat
      let x: CGFloat
      let y: CGFloat

    }

    /// No shadow
    static let none = Style(color: .clear, radius: 0, x: 0, y: 0)

    /// Subtle shadow (2pt) - Minimal elevation
    static let subtle = Style(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

    /// Small shadow (4pt) - Buttons, small cards
    static let small = Style(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

    /// Card shadow (6pt) - Standard cards, list items
    static let card = Style(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)

    /// Medium shadow (8pt) - Floating elements
    static let medium = Style(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

    /// Elevated shadow (12pt) - Modals, popovers
    static let elevated = Style(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

    /// Large shadow (16pt) - Full-screen overlays
    static let large = Style(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)

    /// Search overlay shadow (20pt) - Floating search modal
    static let searchOverlay = Style(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)

    /// Shadow gradient overlay for notes stack to indicate overflow
    /// Sits above the notes stack to show "more notes above"
    static var notesOverflowGradient: LinearGradient {
      LinearGradient(
        gradient: Gradient(colors: [
          Color.black.opacity(0.15),
          Color.black.opacity(0.05),
          Color.clear
        ]),
        startPoint: .top,
        endPoint: .bottom,
      )
    }

    /// Bottom fade gradient for scrollable content
    static var bottomFadeGradient: LinearGradient {
      LinearGradient(
        gradient: Gradient(colors: [
          Color.clear,
          Color.black.opacity(0.05),
          Color.black.opacity(0.15)
        ]),
        startPoint: .top,
        endPoint: .bottom,
      )
    }
  }
}

// MARK: - View Extension for Shadows

extension View {
  /// Applies a design system shadow style to the view
  /// - Parameter style: The shadow style to apply
  /// - Returns: A view with the shadow applied
  func dsShadow(_ style: DS.Shadows.Style) -> some View {
    shadow(
      color: style.color,
      radius: style.radius,
      x: style.x,
      y: style.y,
    )
  }
}
