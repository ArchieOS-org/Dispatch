//
//  Typography.swift
//  Dispatch
//
//  Design Tokens - Typography
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI

extension DS {
  /// Typography tokens using system fonts with Dynamic Type support.
  /// All fonts scale automatically based on user accessibility settings.
  enum Typography {
    /// Typography for stage cards in menu/sidebar grid.
    /// Uses Dynamic Type styles for accessibility compliance.
    enum StageCards {
      /// PRIMARY: Icon font - scales with Dynamic Type
      static let primarySemibold = Font.title.weight(.semibold)

      /// PRIMARY: Count font - scales with Dynamic Type
      static let primaryBold = Font.title.weight(.bold)

      /// SECONDARY: Label font - scales with Dynamic Type
      static let secondary = Font.system(size: 20, weight: .medium)
    }

    /// Large title (32pt bold) - Screen titles, hero text
    static let largeTitle = Font.largeTitle.weight(.bold)

    /// Title (22pt semibold) - Section headers
    static let title = Font.title2.weight(.semibold)

    /// Title 3 (20pt semibold) - Subsection headers
    static let title3 = Font.title3.weight(.semibold)

    /// Headline (17pt semibold) - Card titles, list item primary text
    static let headline = Font.headline

    /// Body (17pt) - Primary content text
    static let body = Font.body

    /// Body secondary (15pt) - Secondary content, descriptions
    static let bodySecondary = Font.subheadline

    /// Callout (16pt) - Emphasized body text
    static let callout = Font.callout

    /// Caption (12pt) - Timestamps, metadata, labels
    static let caption = Font.caption

    /// Caption secondary (11pt) - Smaller metadata
    static let captionSecondary = Font.caption2

    /// Footnote (13pt) - Notes, hints
    static let footnote = Font.footnote

    /// Monospace body - Code, IDs, technical text
    static let mono = Font.system(.body, design: .monospaced)

    /// Monospace caption - Small technical text
    static let monoCaption = Font.system(.caption, design: .monospaced)

    /// Monospace small - Debugging, logs
    static let monoSmall = Font.system(.caption2, design: .monospaced)

    /// Large title that collapses (32pt → 18pt on scroll)
    static let detailLargeTitle = Font.system(size: 32, weight: .bold)

    /// Collapsed header title
    static let detailCollapsedTitle = Font.system(size: 18, weight: .semibold)

  }
}
