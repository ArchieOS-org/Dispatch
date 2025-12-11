//
//  IconSystem.swift
//  Dispatch
//
//  Design Tokens - SF Symbols Icon System
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI

extension DS {
    /// SF Symbol icon tokens organized by purpose.
    /// All icons are SF Symbol system names for consistency and adaptability.
    enum Icons {
        // MARK: - Priority Indicators

        /// Simple filled circle for priority dots
        static let priorityDot = "circle.fill"

        // MARK: - Sync Status Icons

        /// Icons for sync state indicators
        enum Sync {
            /// Synced successfully (ok)
            static let ok = "checkmark.icloud.fill"

            /// Currently syncing
            static let syncing = "arrow.triangle.2.circlepath.icloud"

            /// Idle state (nothing happening)
            static let idle = "icloud"

            /// Sync error
            static let error = "exclamationmark.icloud.fill"

            /// Offline state
            static let offline = "icloud.slash"

            /// Returns the appropriate icon for a sync status
            static func icon(for status: SyncStatus) -> String {
                switch status {
                case .idle: return idle
                case .syncing: return syncing
                case .ok: return ok
                case .error: return error
                }
            }
        }

        // MARK: - Task/Activity Status Icons

        /// Icons for task and activity status states
        enum StatusIcons {
            /// Open/New task
            static let open = "circle"

            /// In progress task
            static let inProgress = "circle.lefthalf.filled"

            /// Completed task
            static let completed = "checkmark.circle.fill"

            /// Deleted task
            static let deleted = "trash.circle"

            /// Returns the appropriate icon for a task status
            static func icon(for status: TaskStatus) -> String {
                switch status {
                case .open: return open
                case .inProgress: return inProgress
                case .completed: return completed
                case .deleted: return deleted
                }
            }

            /// Returns the appropriate icon for an activity status
            static func icon(for status: ActivityStatus) -> String {
                switch status {
                case .open: return open
                case .inProgress: return inProgress
                case .completed: return completed
                case .deleted: return deleted
                }
            }
        }

        // MARK: - Claim State Icons

        /// Icons for work item claim states
        enum Claim {
            /// Unclaimed - available to claim
            static let unclaimed = "person.badge.plus"

            /// Claimed by current user
            static let claimed = "person.fill.checkmark"

            /// Claimed by another user
            static let claimedByOther = "person.fill"

            /// Release claim action
            static let release = "person.badge.minus"

            /// Returns the appropriate icon for a claim state
            static func icon(for state: ClaimState) -> String {
                switch state {
                case .unclaimed: return unclaimed
                case .claimedByMe: return claimed
                case .claimedByOther: return claimedByOther
                }
            }
        }

        // MARK: - Action Icons

        /// Icons for common user actions
        enum Action {
            /// Edit action
            static let edit = "pencil"

            /// Edit in circle (for buttons)
            static let editCircle = "pencil.circle"

            /// Delete action
            static let delete = "trash"

            /// Delete in circle (for buttons)
            static let deleteCircle = "trash.circle"

            /// Add/Create action
            static let add = "plus"

            /// Add in circle (for buttons)
            static let addCircle = "plus.circle.fill"

            /// Save/Confirm action
            static let save = "checkmark"

            /// Save in circle (for buttons)
            static let saveCircle = "checkmark.circle.fill"

            /// Cancel/Close action
            static let cancel = "xmark"

            /// Cancel in circle (for buttons)
            static let cancelCircle = "xmark.circle"

            /// Share action
            static let share = "square.and.arrow.up"

            /// More options (ellipsis)
            static let more = "ellipsis"

            /// More in circle
            static let moreCircle = "ellipsis.circle"

            /// Refresh/Reload
            static let refresh = "arrow.clockwise"
        }

        // MARK: - Navigation Icons

        /// Icons for navigation elements
        enum Navigation {
            /// Back arrow
            static let back = "chevron.left"

            /// Forward arrow
            static let forward = "chevron.right"

            /// Up arrow
            static let up = "chevron.up"

            /// Down arrow
            static let down = "chevron.down"

            /// Close/Dismiss
            static let close = "xmark"

            /// Menu (hamburger)
            static let menu = "line.3.horizontal"

            /// Settings gear
            static let settings = "gearshape"

            /// Settings gear filled
            static let settingsFill = "gearshape.fill"

            /// Search
            static let search = "magnifyingglass"

            /// Filter
            static let filter = "line.3.horizontal.decrease.circle"
        }

        // MARK: - Entity Type Icons

        /// Icons representing different entity types
        enum Entity {
            /// Task entity
            static let task = "checkmark.square"

            /// Task entity filled
            static let taskFill = "checkmark.square.fill"

            /// Activity entity
            static let activity = "calendar"

            /// Activity entity filled
            static let activityFill = "calendar.circle.fill"

            /// Listing/Property entity
            static let listing = "house"

            /// Listing entity filled
            static let listingFill = "house.fill"

            /// Note entity
            static let note = "note.text"

            /// Subtask entity
            static let subtask = "checklist"

            /// User entity
            static let user = "person.circle"

            /// User entity filled
            static let userFill = "person.circle.fill"

            /// Team/Group
            static let team = "person.2"

            /// Team filled
            static let teamFill = "person.2.fill"
        }

        // MARK: - Activity Type Icons

        /// Icons for specific activity types
        enum ActivityType {
            /// Phone call
            static let call = "phone"

            /// Phone call filled
            static let callFill = "phone.fill"

            /// Email
            static let email = "envelope"

            /// Email filled
            static let emailFill = "envelope.fill"

            /// Meeting
            static let meeting = "person.2.circle"

            /// Show property
            static let showProperty = "house.and.flag"

            /// Follow up
            static let followUp = "arrow.uturn.backward.circle"

            /// Other/General
            static let other = "square.grid.2x2"
        }

        // MARK: - Notification & Alert Icons

        /// Icons for notifications and alerts
        enum Alert {
            /// Warning triangle
            static let warning = "exclamationmark.triangle"

            /// Warning filled
            static let warningFill = "exclamationmark.triangle.fill"

            /// Error/Critical
            static let error = "xmark.octagon"

            /// Error filled
            static let errorFill = "xmark.octagon.fill"

            /// Info
            static let info = "info.circle"

            /// Info filled
            static let infoFill = "info.circle.fill"

            /// Success checkmark
            static let success = "checkmark.circle"

            /// Success filled
            static let successFill = "checkmark.circle.fill"

            /// Bell notification
            static let notification = "bell"

            /// Bell notification filled
            static let notificationFill = "bell.fill"

            /// Bell with badge
            static let notificationBadge = "bell.badge"
        }

        // MARK: - Time & Date Icons

        /// Icons for time and date related elements
        enum Time {
            /// Clock
            static let clock = "clock"

            /// Clock filled
            static let clockFill = "clock.fill"

            /// Calendar
            static let calendar = "calendar"

            /// Calendar with clock (scheduled)
            static let scheduled = "calendar.badge.clock"

            /// Overdue (clock with exclamation)
            static let overdue = "clock.badge.exclamationmark"

            /// Timer
            static let timer = "timer"
        }
    }
}
