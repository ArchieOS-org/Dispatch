//
//  DSTypography.swift
//  DesignSystem
//
//  Design Tokens - Typography
//  All fonts support Dynamic Type for accessibility.
//

import SwiftUI

extension DS {
  /// Typography tokens using system fonts with Dynamic Type support.
  /// All fonts scale automatically based on user accessibility settings.
  public enum Typography {
    /// Typography for stage cards in menu/sidebar grid.
    /// Uses Dynamic Type styles for accessibility compliance.
    public enum StageCards {
      /// PRIMARY: Icon font - scales with Dynamic Type
      public static let primarySemibold = Font.title3.weight(.semibold)

      /// PRIMARY: Count font - scales with Dynamic Type
      public static let primaryBold = Font.title3.weight(.bold)

      /// SECONDARY: Label font - scales with Dynamic Type
      public static let secondary = Font.body.weight(.medium)
    }

    /// Large title (32pt bold) - Screen titles, hero text
    public static let largeTitle = Font.largeTitle.weight(.bold)

    /// Title (22pt semibold) - Section headers
    public static let title = Font.title2.weight(.semibold)

    /// Title 3 (20pt semibold) - Subsection headers
    public static let title3 = Font.title3.weight(.semibold)

    /// Headline (17pt semibold) - Card titles, list item primary text
    public static let headline = Font.headline

    /// Body (17pt) - Primary content text
    public static let body = Font.body

    /// Body secondary (15pt) - Secondary content, descriptions
    public static let bodySecondary = Font.subheadline

    /// Callout (16pt) - Emphasized body text
    public static let callout = Font.callout

    /// Caption (12pt) - Timestamps, metadata, labels
    public static let caption = Font.caption

    /// Caption secondary (11pt) - Smaller metadata
    public static let captionSecondary = Font.caption2

    /// Footnote (13pt) - Notes, hints
    public static let footnote = Font.footnote

    /// Monospace body - Code, IDs, technical text
    public static let mono = Font.system(.body, design: .monospaced)

    /// Monospace caption - Small technical text
    public static let monoCaption = Font.system(.caption, design: .monospaced)

    /// Monospace small - Debugging, logs
    public static let monoSmall = Font.system(.caption2, design: .monospaced)

    /// Large title that collapses (32pt -> 18pt on scroll)
    public static let detailLargeTitle = Font.system(size: 32, weight: .bold)

    /// Collapsed header title
    public static let detailCollapsedTitle = Font.system(size: 18, weight: .semibold)
  }
}
