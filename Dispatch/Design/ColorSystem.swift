//
//  ColorSystem.swift
//  Dispatch
//
//  Design Tokens - Semantic Color System
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DS {
    /// Semantic color tokens with automatic dark mode support.
    /// Colors are grouped by purpose and integrate with existing domain enums.
    enum Colors {
        // MARK: - Priority Colors

        /// Colors for task/activity priority levels
        enum PriorityColors {
            static let low = Color.gray
            static let medium = Color.blue
            static let high = Color.orange
            static let urgent = Color.red

            /// Returns the appropriate color for a priority level
            static func color(for priority: Priority) -> Color {
                switch priority {
                case .low: return low
                case .medium: return medium
                case .high: return high
                case .urgent: return urgent
                }
            }
        }

        // MARK: - Task/Activity Status Colors

        /// Colors for task and activity status states
        enum Status {
            static let open = Color.blue
            static let inProgress = Color.orange
            static let completed = Color.green
            static let deleted = Color.gray.opacity(0.5)

            /// Returns the appropriate color for a task status
            static func color(for status: TaskStatus) -> Color {
                switch status {
                case .open: return open
                case .inProgress: return inProgress
                case .completed: return completed
                case .deleted: return deleted
                }
            }

            /// Returns the appropriate color for an activity status
            static func color(for status: ActivityStatus) -> Color {
                switch status {
                case .open: return open
                case .inProgress: return inProgress
                case .completed: return completed
                case .deleted: return deleted
                }
            }
        }

        // MARK: - Sync Status Colors

        /// Colors for sync state indicators
        enum Sync {
            static let ok = Color.green
            static let syncing = Color.blue
            static let idle = Color.gray
            static let error = Color.red

            /// Returns the appropriate color for a sync status
            static func color(for status: SyncStatus) -> Color {
                switch status {
                case .idle: return idle
                case .syncing: return syncing
                case .ok: return ok
                case .error: return error
                }
            }
        }

        // MARK: - Claim State Colors

        /// Colors for work item claim states
        enum Claim {
            static let unclaimed = Color.gray
            static let claimedByMe = Color.green
            static let claimedByOther = Color.orange

            /// Returns the appropriate color for a claim state
            static func color(for state: ClaimState) -> Color {
                switch state {
                case .unclaimed: return unclaimed
                case .claimedByMe: return claimedByMe
                case .claimedByOther: return claimedByOther
                }
            }
        }

        // MARK: - Background Colors (Adaptive)

        /// Semantic background colors that adapt to light/dark mode
        enum Background {
            /// Primary background - custom theme colors
            /// Light mode: #FAF9FF, Dark mode: #262624
            #if canImport(UIKit)
            static let primary = Color(uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 38/255, green: 38/255, blue: 36/255, alpha: 1)    // #262624
                    : UIColor(red: 250/255, green: 249/255, blue: 255/255, alpha: 1) // #FAF9FF
            })
            #else
            static let primary = Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                    ? NSColor(red: 38/255, green: 38/255, blue: 36/255, alpha: 1)    // #262624
                    : NSColor(red: 250/255, green: 249/255, blue: 255/255, alpha: 1) // #FAF9FF
            } ?? .windowBackgroundColor)
            #endif

            /// Secondary background (subtle gray)
            #if canImport(UIKit)
            static let secondary = Color(uiColor: .secondarySystemBackground)
            #else
            static let secondary = Color(nsColor: .controlBackgroundColor)
            #endif

            /// Tertiary background (deeper gray)
            #if canImport(UIKit)
            static let tertiary = Color(uiColor: .tertiarySystemBackground)
            #else
            static let tertiary = Color(nsColor: .underPageBackgroundColor)
            #endif

            /// Grouped content background
            #if canImport(UIKit)
            static let grouped = Color(uiColor: .systemGroupedBackground)
            #else
            static let grouped = Color(nsColor: .windowBackgroundColor)
            #endif

            /// Grouped secondary background (layered surface above grouped backgrounds)
            #if canImport(UIKit)
            static let groupedSecondary = Color(uiColor: .secondarySystemGroupedBackground)
            #else
            static let groupedSecondary = Color(nsColor: .controlBackgroundColor)
            #endif

            /// Card background (systemGray6)
            #if canImport(UIKit)
            static let card = Color(uiColor: .systemGray6)
            #else
            static let card = Color(nsColor: .controlBackgroundColor)
            #endif

            /// Card background dark variant (systemGray5)
            #if canImport(UIKit)
            static let cardDark = Color(uiColor: .systemGray5)
            #else
            static let cardDark = Color(nsColor: .separatorColor)
            #endif
        }

        // MARK: - Text Colors (Adaptive)

        /// Semantic text colors that adapt to light/dark mode
        enum Text {
            /// Primary text color
            static let primary = Color.primary

            /// Secondary text color (dimmed)
            static let secondary = Color.secondary

            /// Tertiary text color (more dimmed)
            #if canImport(UIKit)
            static let tertiary = Color(uiColor: .tertiaryLabel)
            #else
            static let tertiary = Color(nsColor: .tertiaryLabelColor)
            #endif

            /// Quaternary text color (most dimmed)
            #if canImport(UIKit)
            static let quaternary = Color(uiColor: .quaternaryLabel)
            #else
            static let quaternary = Color(nsColor: .quaternaryLabelColor)
            #endif

            /// Disabled text color
            #if canImport(UIKit)
            static let disabled = Color(uiColor: .quaternaryLabel)
            #else
            static let disabled = Color(nsColor: .quaternaryLabelColor)
            #endif

            /// Placeholder text color
            #if canImport(UIKit)
            static let placeholder = Color(uiColor: .placeholderText)
            #else
            static let placeholder = Color(nsColor: .placeholderTextColor)
            #endif
        }

        // MARK: - UI Element Colors

        /// App accent color
        static let accent = Color.accentColor

        /// Destructive action color (delete, cancel)
        static let destructive = Color.red

        /// Success state color
        static let success = Color.green

        /// Warning state color
        static let warning = Color.orange

        /// Information state color
        static let info = Color.blue

        // MARK: - Border & Separator Colors

        /// Standard border color
        static let border = Color.gray.opacity(0.2)

        /// System separator color
        #if canImport(UIKit)
        static let separator = Color(uiColor: .separator)
        #else
        static let separator = Color(nsColor: .separatorColor)
        #endif

        /// Focused border color
        static let borderFocused = Color.accentColor

        // MARK: - Due Date Colors

        /// Color for overdue items
        static let overdue = Color.red

        /// Color for due soon items (within 24 hours)
        static let dueSoon = Color.orange

        /// Color for normal due dates
        static let dueNormal = Color.secondary

        // MARK: - Progress Colors

        /// Colors for progress indicators (e.g., ProgressCircle)
        enum Progress {
            /// Track ring color - subtle background for unfilled portion
            static let track = DS.Colors.Text.tertiary.opacity(0.3)
        }

        // MARK: - Search Overlay

        /// Semi-transparent scrim behind search overlay
        static let searchScrim = Color.black.opacity(0.4)

        // MARK: - Role Colors

        /// Colors for role/audience indicators - uses system colors for dark mode compatibility
        enum RoleColors {
            /// Indigo for admin role - authoritative, analytical, cool-toned
            static let admin = Color.indigo
            /// Orange for marketing role - energetic, creative, warm-toned
            static let marketing = Color.orange
            /// Neutral gray for "all" view (unused if no ring for All)
            static let all = Color.gray

            /// Returns the appropriate color for a role
            static func color(for role: Role) -> Color {
                switch role {
                case .admin: return admin
                case .marketing: return marketing
                }
            }
        }

        // MARK: - Listing Stage Colors

        /// Colors for listing lifecycle stages
        enum Stage {
            static let pending = Color.gray
            static let workingOn = Color.orange
            static let live = Color.green
            static let sold = Color.blue
            static let reList = Color.purple
            static let done = Color.gray.opacity(0.6)

            /// Returns the appropriate color for a listing stage
            static func color(for stage: ListingStage) -> Color {
                switch stage {
                case .pending: return pending
                case .workingOn: return workingOn
                case .live: return live
                case .sold: return sold
                case .reList: return reList
                case .done: return done
                }
            }
        }

        // MARK: - Section Colors

        /// Colors for main navigation sections
        enum Section {
            static let myWorkspace = Color.blue
            static let properties = Color.teal
            static let listings = Color.green
            static let realtors = Color.indigo
            static let tasks = Color.blue
            static let activities = Color.orange
        }
    }
}
