//
//  DSRadius.swift
//  DesignSystem
//
//  Design Tokens - Corner Radius Scale
//  Extracted from spacing for semantic clarity.
//

import SwiftUI

extension DS {
  /// Corner radius tokens for consistent rounding across the app.
  public enum Radius {
    /// Small radius (4pt) - subtle rounding
    public static let small: CGFloat = 4

    /// Medium radius (8pt) - cards, buttons
    public static let medium: CGFloat = 8

    /// Large radius (16pt) - modals, sheets
    public static let large: CGFloat = 16

    /// Card corner radius (10pt) - as specified in design
    public static let card: CGFloat = 10

    /// Search overlay modal corner radius
    public static let searchModal: CGFloat = 20
  }
}
