//
//  ColorSystem.swift
//  Dispatch
//
//  Design Tokens - Semantic Color System
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI

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
            /// Primary background (white/dark)
            static let primary = Color(uiColor: .systemBackground)

            /// Secondary background (subtle gray)
            static let secondary = Color(uiColor: .secondarySystemBackground)

            /// Tertiary background (deeper gray)
            static let tertiary = Color(uiColor: .tertiarySystemBackground)

            /// Grouped content background
            static let grouped = Color(uiColor: .systemGroupedBackground)

            /// Card background (systemGray6)
            static let card = Color(uiColor: .systemGray6)

            /// Card background dark variant (systemGray5)
            static let cardDark = Color(uiColor: .systemGray5)
        }

        // MARK: - Text Colors (Adaptive)

        /// Semantic text colors that adapt to light/dark mode
        enum Text {
            /// Primary text color
            static let primary = Color.primary

            /// Secondary text color (dimmed)
            static let secondary = Color.secondary

            /// Tertiary text color (more dimmed)
            static let tertiary = Color(uiColor: .tertiaryLabel)

            /// Quaternary text color (most dimmed)
            static let quaternary = Color(uiColor: .quaternaryLabel)

            /// Disabled text color
            static let disabled = Color(uiColor: .quaternaryLabel)

            /// Placeholder text color
            static let placeholder = Color(uiColor: .placeholderText)
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
        static let separator = Color(uiColor: .separator)

        /// Focused border color
        static let borderFocused = Color.accentColor

        // MARK: - Due Date Colors

        /// Color for overdue items
        static let overdue = Color.red

        /// Color for due soon items (within 24 hours)
        static let dueSoon = Color.orange

        /// Color for normal due dates
        static let dueNormal = Color.secondary
    }
}
