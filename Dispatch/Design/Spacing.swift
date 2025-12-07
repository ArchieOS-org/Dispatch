//
//  Spacing.swift
//  Dispatch
//
//  Design Tokens - Spacing & Layout Constants
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI

extension DS {
    /// Spacing tokens following a 4pt grid system.
    /// Use these for consistent padding, margins, and gaps throughout the app.
    enum Spacing {
        // MARK: - Base Scale (4pt grid)

        /// 2pt - Extra extra small spacing
        static let xxs: CGFloat = 2

        /// 4pt - Extra small spacing
        static let xs: CGFloat = 4

        /// 8pt - Small spacing
        static let sm: CGFloat = 8

        /// 12pt - Medium spacing (default)
        static let md: CGFloat = 12

        /// 16pt - Large spacing
        static let lg: CGFloat = 16

        /// 20pt - Extra large spacing
        static let xl: CGFloat = 20

        /// 24pt - Extra extra large spacing
        static let xxl: CGFloat = 24

        /// 32pt - Extra extra extra large spacing
        static let xxxl: CGFloat = 32

        // MARK: - Component-Specific (from spec)

        /// Standard card internal padding
        static let cardPadding: CGFloat = 12

        /// Spacing between major sections
        static let sectionSpacing: CGFloat = 20

        /// Default spacing for stacked items
        static let stackSpacing: CGFloat = 12

        // MARK: - Notes Section (from spec)

        /// Fixed height for the notes stack container (shows ~3 notes partially)
        static let notesStackHeight: CGFloat = 140

        /// Minimum height for note input text editor
        static let noteInputMinHeight: CGFloat = 80

        /// Maximum height for note input text editor
        static let noteInputMaxHeight: CGFloat = 200

        /// Height of the shadow gradient overlay above notes
        static let shadowGradientHeight: CGFloat = 12

        /// Offset multiplier for cascading note cards
        static let noteCascadeOffset: CGFloat = 8

        // MARK: - Avatar Sizes

        /// Small avatar (24pt) - inline with text
        static let avatarSmall: CGFloat = 24

        /// Medium avatar (32pt) - list items
        static let avatarMedium: CGFloat = 32

        /// Large avatar (44pt) - detail views, profiles
        static let avatarLarge: CGFloat = 44

        // MARK: - Corner Radius

        /// Small radius (4pt) - subtle rounding
        static let radiusSmall: CGFloat = 4

        /// Medium radius (8pt) - cards, buttons
        static let radiusMedium: CGFloat = 8

        /// Large radius (16pt) - modals, sheets
        static let radiusLarge: CGFloat = 16

        /// Card corner radius (10pt) - as specified in design
        static let radiusCard: CGFloat = 10

        // MARK: - Touch Targets (Apple HIG)

        /// Minimum touch target size (44pt)
        static let minTouchTarget: CGFloat = 44

        // MARK: - Priority Dot

        /// Size of priority indicator dot
        static let priorityDotSize: CGFloat = 8
    }
}
