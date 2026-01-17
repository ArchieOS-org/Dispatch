//
//  DSSpacing.swift
//  DesignSystem
//
//  Design Tokens - Spacing & Layout Constants
//  Based on a 4pt grid system for consistent layout.
//

import SwiftUI

extension DS {
  /// Spacing tokens following a 4pt grid system.
  /// Use these for consistent padding, margins, and gaps throughout the app.
  public enum Spacing {
    /// Stage cards grid configuration for menu/sidebar.
    /// Typography tokens are in DS.Typography.StageCards (Dynamic Type).
    public enum StageCards {
      /// Spacing between cards in the grid
      public static let gridSpacing: CGFloat = 10

      /// Internal card padding (increased for breathing room)
      public static let cardPadding: CGFloat = 16

      /// Minimum card height - allows expansion at larger Dynamic Type sizes
      public static let cardMinHeight: CGFloat = 88

      /// Maximum card height - prevents excessive growth
      public static let cardMaxHeight: CGFloat = 120
    }

    /// Layout constants for page structure
    public enum Layout {
      /// Content side margin (Things 3 style spacious layout)
      public static let pageMargin: CGFloat = 40

      /// Top padding for content to clear the floating traffic lights
      /// and provide visual separation (Things 3 style)
      public static let topHeaderPadding: CGFloat = 20

      /// Font size for the implementation of the "Large Title"
      public static let largeTitleSize: CGFloat = 30

      /// Spacing below the large title before content begins
      public static let titleBottomSpacing: CGFloat = 20

      /// Spacing below navigation title before content (Apple HIG: 20pt)
      /// Use this as the single source of truth for title-to-content spacing
      public static let titleContentSpacing: CGFloat = 20

      /// Maximum width for content in detail views to prevent it from stretching too wide
      public static let maxContentWidth: CGFloat = 800
    }

    // MARK: - Base Spacing Scale

    /// 2pt - Extra extra small spacing
    public static let xxs: CGFloat = 2

    /// 4pt - Extra small spacing
    public static let xs: CGFloat = 4

    /// 8pt - Small spacing
    public static let sm: CGFloat = 8

    /// 12pt - Medium spacing (default)
    public static let md: CGFloat = 12

    /// 16pt - Large spacing
    public static let lg: CGFloat = 16

    /// 20pt - Extra large spacing
    public static let xl: CGFloat = 20

    /// 24pt - Extra extra large spacing
    public static let xxl: CGFloat = 24

    /// 32pt - Extra extra extra large spacing
    public static let xxxl: CGFloat = 32

    // MARK: - Semantic Spacing

    /// Standard card internal padding
    public static let cardPadding: CGFloat = 12

    /// Spacing between major sections
    public static let sectionSpacing: CGFloat = 20

    /// Default spacing for stacked items
    public static let stackSpacing: CGFloat = 12

    /// Vertical padding for list row components (compact design)
    public static let listRowPadding: CGFloat = 8

    /// Leading indentation for work item rows in list contexts
    public static let workItemRowIndent: CGFloat = 24

    // MARK: - Notes Stack

    /// Fixed height for the notes stack container (shows ~3 notes partially)
    public static let notesStackHeight: CGFloat = 140

    /// Minimum height for note input text editor
    public static let noteInputMinHeight: CGFloat = 80

    /// Maximum height for note input text editor
    public static let noteInputMaxHeight: CGFloat = 200

    /// Height of the shadow gradient overlay above notes
    public static let shadowGradientHeight: CGFloat = 12

    /// Offset multiplier for cascading note cards
    public static let noteCascadeOffset: CGFloat = 8

    // MARK: - Avatar Sizes

    /// Small avatar (24pt) - inline with text
    public static let avatarSmall: CGFloat = 24

    /// Medium avatar (32pt) - list items
    public static let avatarMedium: CGFloat = 32

    /// Large avatar (44pt) - detail views, profiles
    public static let avatarLarge: CGFloat = 44

    // MARK: - Touch Targets

    /// Minimum touch target size (44pt)
    public static let minTouchTarget: CGFloat = 44

    // MARK: - Indicators

    /// Size of priority indicator dot
    public static let priorityDotSize: CGFloat = 8

    /// Size of role dot indicator
    public static let roleDotSize: CGFloat = 6

    /// Stroke width for view state ring around overflow menu
    public static let viewStateRingStroke: CGFloat = 1.5

    /// Diameter of the view state ring
    public static let viewStateRingDiameter: CGFloat = 28

    /// Opacity for role indicators
    public static let roleIndicatorOpacity = 0.6

    // MARK: - Gestures

    /// Duration for long-press gesture to cycle views
    public static let longPressDuration = 0.4

    // MARK: - Search

    /// Pull distance to trigger search overlay
    public static let searchPullThreshold: CGFloat = 60

    /// Top grab area height for pull-down gesture
    public static let searchPullZoneHeight: CGFloat = 32

    /// Search bar height
    public static let searchBarHeight: CGFloat = 48

    /// Search result row height
    public static let searchResultRowHeight: CGFloat = 56

    /// Search overlay modal horizontal padding
    public static let searchModalPadding: CGFloat = 16

    /// Search overlay modal max width (for larger screens)
    public static let searchModalMaxWidth: CGFloat = 500

    /// Pull-to-search indicator icon size
    public static let searchPullIndicatorSize: CGFloat = 24

    /// Pull-to-search armed state background padding
    public static let searchPullArmedPadding: CGFloat = 12

    // MARK: - Sidebar

    /// Minimum sidebar width
    public static let sidebarMinWidth: CGFloat = 200

    /// Maximum sidebar width
    public static let sidebarMaxWidth: CGFloat = 400

    /// Default sidebar width
    public static let sidebarDefaultWidth: CGFloat = 240

    /// Width of the invisible drag handle hit area
    public static let sidebarDragHandleWidth: CGFloat = 16

    /// Height of the visible drag handle indicator
    public static let sidebarDragHandleHeight: CGFloat = 28

    // MARK: - Bottom Toolbar

    /// Bottom toolbar height
    public static let bottomToolbarHeight: CGFloat = 44

    /// Bottom toolbar icon button size
    public static let bottomToolbarButtonSize: CGFloat = 36

    /// Bottom toolbar icon size
    public static let bottomToolbarIconSize: CGFloat = 18

    /// Bottom toolbar horizontal padding
    public static let bottomToolbarPadding: CGFloat = 12

    // MARK: - Floating Buttons

    /// Standard floating button size (44pt - Apple HIG minimum touch target)
    public static let floatingButtonSize: CGFloat = 44

    /// Large floating button size for primary FAB (56pt)
    public static let floatingButtonSizeLarge: CGFloat = 56

    /// Horizontal margin from screen edge to button edge
    /// For 56pt buttons: button CENTER is 48pt from screen edge
    public static let floatingButtonMargin: CGFloat = 20

    /// Vertical inset from safe area bottom to button edge
    /// For 56pt buttons: button CENTER is 44pt above safe area (lower, Things 3-style)
    public static let floatingButtonBottomInset: CGFloat = 16

    /// Icon size within standard floating buttons (44pt)
    public static let floatingButtonIconSize: CGFloat = 20

    /// Icon size within large floating buttons (56pt)
    public static let floatingButtonIconSizeLarge: CGFloat = 24

    /// Bottom inset for scroll content when floating buttons are present (iOS/iPadOS only)
    /// Combines button size (56pt) + bottom inset (16pt) = 72pt clearance
    public static let floatingButtonScrollInset: CGFloat = floatingButtonSizeLarge + floatingButtonBottomInset

    // MARK: - Window Sizing (macOS)

    /// Minimum window width (macOS) - accommodates sidebar + content
    public static let windowMinWidth: CGFloat = 600

    /// Minimum window height (macOS)
    public static let windowMinHeight: CGFloat = 400

    /// Default window width (macOS) - comfortable working size
    public static let windowDefaultWidth: CGFloat = 1000

    /// Default window height (macOS)
    public static let windowDefaultHeight: CGFloat = 700

    // MARK: - Backward Compatibility (Radius Aliases)
    // These are deprecated in favor of DS.Radius.* but kept for backward compatibility

    /// Small radius (4pt) - subtle rounding
    /// - Note: Deprecated, use DS.Radius.small instead
    public static let radiusSmall: CGFloat = DS.Radius.small

    /// Medium radius (8pt) - cards, buttons
    /// - Note: Deprecated, use DS.Radius.medium instead
    public static let radiusMedium: CGFloat = DS.Radius.medium

    /// Large radius (16pt) - modals, sheets
    /// - Note: Deprecated, use DS.Radius.large instead
    public static let radiusLarge: CGFloat = DS.Radius.large

    /// Card corner radius (10pt) - as specified in design
    /// - Note: Deprecated, use DS.Radius.card instead
    public static let radiusCard: CGFloat = DS.Radius.card

    /// Search overlay modal corner radius
    /// - Note: Deprecated, use DS.Radius.searchModal instead
    public static let searchModalRadius: CGFloat = DS.Radius.searchModal
  }
}
