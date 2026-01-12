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
    /// Stage cards grid configuration for menu/sidebar.
    /// Typography tokens are in DS.Typography.StageCards (Dynamic Type).
    enum StageCards {
      /// Spacing between cards in the grid
      static let gridSpacing: CGFloat = 10

      /// Internal card padding (increased for breathing room)
      static let cardPadding: CGFloat = 16

      /// Minimum card height - allows expansion at larger Dynamic Type sizes
      static let cardMinHeight: CGFloat = 88

      /// Maximum card height - prevents excessive growth
      static let cardMaxHeight: CGFloat = 120
    }

    enum Layout {
      /// Content side margin (Things 3 style spacious layout)
      static let pageMargin: CGFloat = 40

      /// Top padding for content to clear the floating traffic lights
      /// and provide visual separation (Things 3 style)
      static let topHeaderPadding: CGFloat = 20

      /// Font size for the implementation of the "Large Title"
      static let largeTitleSize: CGFloat = 30

      /// Spacing below the large title before content begins
      static let titleBottomSpacing: CGFloat = 20

      /// Spacing below navigation title before content (Apple HIG: 20pt)
      /// Use this as the single source of truth for title-to-content spacing
      static let titleContentSpacing: CGFloat = 20

      /// Maximum width for content in detail views to prevent it from stretching too wide
      static let maxContentWidth: CGFloat = 800
    }

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

    /// Standard card internal padding
    static let cardPadding: CGFloat = 12

    /// Spacing between major sections
    static let sectionSpacing: CGFloat = 20

    /// Default spacing for stacked items
    static let stackSpacing: CGFloat = 12

    /// Vertical padding for list row components (compact design)
    static let listRowPadding: CGFloat = 8

    /// Leading indentation for work item rows in list contexts
    static let workItemRowIndent: CGFloat = 24

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

    /// Small avatar (24pt) - inline with text
    static let avatarSmall: CGFloat = 24

    /// Medium avatar (32pt) - list items
    static let avatarMedium: CGFloat = 32

    /// Large avatar (44pt) - detail views, profiles
    static let avatarLarge: CGFloat = 44

    /// Small radius (4pt) - subtle rounding
    static let radiusSmall: CGFloat = 4

    /// Medium radius (8pt) - cards, buttons
    static let radiusMedium: CGFloat = 8

    /// Large radius (16pt) - modals, sheets
    static let radiusLarge: CGFloat = 16

    /// Card corner radius (10pt) - as specified in design
    static let radiusCard: CGFloat = 10

    /// Minimum touch target size (44pt)
    static let minTouchTarget: CGFloat = 44

    /// Size of priority indicator dot
    static let priorityDotSize: CGFloat = 8

    /// Size of role dot indicator
    static let roleDotSize: CGFloat = 6

    /// Stroke width for view state ring around overflow menu
    static let viewStateRingStroke: CGFloat = 1.5

    /// Diameter of the view state ring
    static let viewStateRingDiameter: CGFloat = 28

    /// Opacity for role indicators
    static let roleIndicatorOpacity = 0.6

    /// Duration for long-press gesture to cycle views
    static let longPressDuration = 0.4

    /// Pull distance to trigger search overlay
    static let searchPullThreshold: CGFloat = 60

    /// Top grab area height for pull-down gesture
    static let searchPullZoneHeight: CGFloat = 32

    /// Search bar height
    static let searchBarHeight: CGFloat = 48

    /// Search result row height
    static let searchResultRowHeight: CGFloat = 56

    /// Search overlay modal corner radius
    static let searchModalRadius: CGFloat = 20

    /// Search overlay modal horizontal padding
    static let searchModalPadding: CGFloat = 16

    /// Search overlay modal max width (for larger screens)
    static let searchModalMaxWidth: CGFloat = 500

    /// Pull-to-search indicator icon size
    static let searchPullIndicatorSize: CGFloat = 24

    /// Pull-to-search armed state background padding
    static let searchPullArmedPadding: CGFloat = 12

    /// Minimum sidebar width
    static let sidebarMinWidth: CGFloat = 200

    /// Maximum sidebar width
    static let sidebarMaxWidth: CGFloat = 400

    /// Default sidebar width
    static let sidebarDefaultWidth: CGFloat = 240

    /// Width of the invisible drag handle hit area
    static let sidebarDragHandleWidth: CGFloat = 16

    /// Height of the visible drag handle indicator
    static let sidebarDragHandleHeight: CGFloat = 28

    /// Bottom toolbar height
    static let bottomToolbarHeight: CGFloat = 44

    /// Bottom toolbar icon button size
    static let bottomToolbarButtonSize: CGFloat = 36

    /// Bottom toolbar icon size
    static let bottomToolbarIconSize: CGFloat = 18

    /// Bottom toolbar horizontal padding
    static let bottomToolbarPadding: CGFloat = 12

    // MARK: - Floating Buttons

    /// Standard floating button size (44pt - Apple HIG minimum touch target)
    static let floatingButtonSize: CGFloat = 44

    /// Large floating button size for primary FAB (56pt)
    static let floatingButtonSizeLarge: CGFloat = 56

    /// Horizontal margin from screen edge to button edge
    /// For 56pt buttons: button CENTER is 48pt from screen edge
    static let floatingButtonMargin: CGFloat = 20

    /// Vertical inset from safe area bottom to button edge
    /// For 56pt buttons: button CENTER is 44pt above safe area (lower, Things 3-style)
    static let floatingButtonBottomInset: CGFloat = 16

    /// Icon size within standard floating buttons (44pt)
    static let floatingButtonIconSize: CGFloat = 20

    /// Icon size within large floating buttons (56pt)
    static let floatingButtonIconSizeLarge: CGFloat = 24

  }
}
