//
//  Extensions.swift
//  DesignSystem
//
//  Reusable View extensions for common patterns.
//

import SwiftUI

// MARK: - Conditional Modifiers

extension View {
  /// Conditionally applies a modifier to the view.
  ///
  /// Usage:
  /// ```swift
  /// Text("Hello")
  ///   .if(isHighlighted) { view in
  ///     view.foregroundColor(.yellow)
  ///   }
  /// ```
  @ViewBuilder
  public func `if`<Content: View>(
    _ condition: Bool,
    transform: (Self) -> Content
  ) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }

  /// Conditionally applies one of two modifiers based on a condition.
  ///
  /// Usage:
  /// ```swift
  /// Text("Hello")
  ///   .if(isHighlighted) { view in
  ///     view.foregroundColor(.yellow)
  ///   } else: { view in
  ///     view.foregroundColor(.gray)
  ///   }
  /// ```
  @ViewBuilder
  public func `if`<TrueContent: View, FalseContent: View>(
    _ condition: Bool,
    transform: (Self) -> TrueContent,
    else elseTransform: (Self) -> FalseContent
  ) -> some View {
    if condition {
      transform(self)
    } else {
      elseTransform(self)
    }
  }
}

// MARK: - Frame Helpers

extension View {
  /// Applies both minimum and maximum frame constraints.
  ///
  /// Usage:
  /// ```swift
  /// Rectangle()
  ///   .frameRange(minWidth: 100, maxWidth: 200)
  /// ```
  public func frameRange(
    minWidth: CGFloat? = nil,
    maxWidth: CGFloat? = nil,
    minHeight: CGFloat? = nil,
    maxHeight: CGFloat? = nil,
    alignment: Alignment = .center
  ) -> some View {
    frame(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      alignment: alignment
    )
  }
}
