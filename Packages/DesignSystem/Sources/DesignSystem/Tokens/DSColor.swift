//
//  DSColor.swift
//  DesignSystem
//
//  Design Tokens - Semantic Color System
//  All colors adapt automatically to light/dark mode.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - DS.Colors

extension DS {
  /// Semantic color tokens with automatic dark mode support.
  /// Colors are grouped by purpose.
  public enum Colors {
    /// Colors for task/activity priority levels
    public enum PriorityColors {
      public static let low = Color.gray
      public static let medium = Color.blue
      public static let high = Color.orange
      public static let urgent = Color.red
    }

    /// Colors for task and activity status states
    public enum Status {
      public static let open = Color.blue
      public static let inProgress = Color.orange
      public static let completed = Color.green
      public static let deleted = Color.gray.opacity(0.5)
    }

    /// Colors for sync state indicators
    public enum Sync {
      public static let ok = Color.green
      public static let syncing = Color.blue
      public static let idle = Color.gray
      public static let error = Color.red
    }

    /// Semantic background colors that adapt to light/dark mode
    public enum Background {
      /// Primary background - custom theme colors
      /// Light mode: #FAF9FF, Dark mode: #262624
      #if canImport(UIKit)
      public static let primary = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
          ? UIColor(red: 38 / 255, green: 38 / 255, blue: 36 / 255, alpha: 1)  // #262624
          : UIColor(red: 250 / 255, green: 249 / 255, blue: 255 / 255, alpha: 1)  // #FAF9FF
      })
      #else
      public static let primary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
          ? NSColor(red: 38 / 255, green: 38 / 255, blue: 36 / 255, alpha: 1)  // #262624
          : NSColor(red: 250 / 255, green: 249 / 255, blue: 255 / 255, alpha: 1)  // #FAF9FF
      })
      #endif

      /// Secondary background (subtle gray)
      #if canImport(UIKit)
      public static let secondary = Color(uiColor: .secondarySystemBackground)
      #else
      public static let secondary = Color(nsColor: .controlBackgroundColor)
      #endif

      /// Tertiary background (deeper gray)
      #if canImport(UIKit)
      public static let tertiary = Color(uiColor: .tertiarySystemBackground)
      #else
      public static let tertiary = Color(nsColor: .underPageBackgroundColor)
      #endif

      /// Grouped content background
      #if canImport(UIKit)
      public static let grouped = Color(uiColor: .systemGroupedBackground)
      #else
      public static let grouped = Color(nsColor: .windowBackgroundColor)
      #endif

      /// Grouped secondary background (layered surface above grouped backgrounds)
      #if canImport(UIKit)
      public static let groupedSecondary = Color(uiColor: .secondarySystemGroupedBackground)
      #else
      public static let groupedSecondary = Color(nsColor: .controlBackgroundColor)
      #endif

      /// Card background (systemGray6)
      #if canImport(UIKit)
      public static let card = Color(uiColor: .systemGray6)
      #else
      public static let card = Color(nsColor: .controlBackgroundColor)
      #endif

      /// Card background dark variant (systemGray5)
      #if canImport(UIKit)
      public static let cardDark = Color(uiColor: .systemGray5)
      #else
      public static let cardDark = Color(nsColor: .separatorColor)
      #endif
    }

    /// Semantic text colors that adapt to light/dark mode
    public enum Text {
      /// Primary text color
      public static let primary = Color.primary

      /// Secondary text color (dimmed)
      public static let secondary = Color.secondary

      /// Tertiary text color (more dimmed)
      #if canImport(UIKit)
      public static let tertiary = Color(uiColor: .tertiaryLabel)
      #else
      public static let tertiary = Color(nsColor: .tertiaryLabelColor)
      #endif

      /// Quaternary text color (most dimmed)
      #if canImport(UIKit)
      public static let quaternary = Color(uiColor: .quaternaryLabel)
      #else
      public static let quaternary = Color(nsColor: .quaternaryLabelColor)
      #endif

      /// Disabled text color
      #if canImport(UIKit)
      public static let disabled = Color(uiColor: .quaternaryLabel)
      #else
      public static let disabled = Color(nsColor: .quaternaryLabelColor)
      #endif

      /// Placeholder text color
      #if canImport(UIKit)
      public static let placeholder = Color(uiColor: .placeholderText)
      #else
      public static let placeholder = Color(nsColor: .placeholderTextColor)
      #endif
    }

    /// Colors for progress indicators (e.g., ProgressCircle)
    public enum Progress {
      /// Track ring color - subtle background for unfilled portion
      public static let track = DS.Colors.Text.tertiary.opacity(0.3)
    }

    /// Colors for role/audience indicators - uses system colors for dark mode compatibility
    public enum RoleColors {
      /// Indigo for admin role - authoritative, analytical, cool-toned
      public static let admin = Color.indigo
      /// Orange for marketing role - energetic, creative, warm-toned
      public static let marketing = Color.orange
      /// Neutral gray for "all" view (unused if no ring for All)
      public static let all = Color.gray
    }

    /// Colors for listing lifecycle stages
    public enum Stage {
      public static let pending = Color.gray
      public static let workingOn = Color.orange
      public static let live = Color.green
      public static let sold = Color.blue
      public static let reList = Color.purple
      public static let done = Color.gray.opacity(0.6)
    }

    /// Colors for main navigation sections
    public enum Section {
      public static let myWorkspace = Color.blue
      public static let properties = Color.teal
      public static let listings = Color.green
      public static let realtors = Color.indigo
      public static let tasks = Color.blue
      public static let activities = Color.orange
    }

    /// App accent color
    public static let accent = Color.accentColor

    /// Destructive action color (delete, cancel)
    public static let destructive = Color.red

    /// Success state color
    public static let success = Color.green

    /// Warning state color
    public static let warning = Color.orange

    /// Information state color
    public static let info = Color.blue

    /// Standard border color
    public static let border = Color.gray.opacity(0.2)

    /// System separator color
    #if canImport(UIKit)
    public static let separator = Color(uiColor: .separator)
    #else
    public static let separator = Color(nsColor: .separatorColor)
    #endif

    /// Focused border color
    public static let borderFocused = Color.accentColor

    /// Color for overdue items
    public static let overdue = Color.red

    /// Color for due soon items (within 24 hours)
    public static let dueSoon = Color.orange

    /// Color for normal due dates
    public static let dueNormal = Color.secondary

    /// Semi-transparent scrim behind search overlay
    public static let searchScrim = Color.black.opacity(0.4)

    /// Semi-transparent scrim behind modal dialogs
    public static let modalScrim = Color.black.opacity(0.4)

    /// Background color for armed pull-to-search state
    public static let searchArmed = Color.blue
  }
}
