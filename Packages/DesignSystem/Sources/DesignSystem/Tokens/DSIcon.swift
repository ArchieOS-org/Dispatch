//
//  DSIcon.swift
//  DesignSystem
//
//  Design Tokens - SF Symbols Icon System
//  All icons are SF Symbol system names for consistency and adaptability.
//

import SwiftUI

extension DS {
  /// SF Symbol icon tokens organized by purpose.
  /// All icons are SF Symbol system names for consistency and adaptability.
  public enum Icons {
    /// Icons for sync state indicators
    public enum Sync {
      /// Synced successfully (ok)
      public static let ok = "checkmark.icloud.fill"

      /// Currently syncing
      public static let syncing = "arrow.triangle.2.circlepath.icloud"

      /// Idle state (nothing happening)
      public static let idle = "icloud"

      /// Sync error
      public static let error = "exclamationmark.icloud.fill"

      /// Offline state
      public static let offline = "icloud.slash"
    }

    /// Icons for task and activity status states
    public enum StatusIcons {
      /// Open/New task
      public static let open = "circle"

      /// In progress task
      public static let inProgress = "circle.lefthalf.filled"

      /// Completed task
      public static let completed = "checkmark.circle.fill"

      /// Deleted task
      public static let deleted = "trash.circle"
    }

    /// Icons for common user actions
    public enum Action {
      /// Edit action
      public static let edit = "pencil"

      /// Edit in circle (for buttons)
      public static let editCircle = "pencil.circle"

      /// Delete action
      public static let delete = "trash"

      /// Delete in circle (for buttons)
      public static let deleteCircle = "trash.circle"

      /// Add/Create action
      public static let add = "plus"

      /// Add in circle (for buttons)
      public static let addCircle = "plus.circle.fill"

      /// Save/Confirm action
      public static let save = "checkmark"

      /// Save in circle (for buttons)
      public static let saveCircle = "checkmark.circle.fill"

      /// Cancel/Close action
      public static let cancel = "xmark"

      /// Cancel in circle (for buttons)
      public static let cancelCircle = "xmark.circle"

      /// Share action
      public static let share = "square.and.arrow.up"

      /// More options (ellipsis)
      public static let more = "ellipsis"

      /// More in circle
      public static let moreCircle = "ellipsis.circle"

      /// Refresh/Reload
      public static let refresh = "arrow.clockwise"
    }

    /// Icons for navigation elements
    public enum Navigation {
      /// Back arrow
      public static let back = "chevron.left"

      /// Up arrow
      public static let up = "chevron.up"

      /// Down arrow
      public static let down = "chevron.down"

      /// Forward arrow
      public static let forward = "chevron.right"

      /// Close/Dismiss
      public static let close = "xmark"

      /// Menu (hamburger)
      public static let menu = "line.3.horizontal"

      /// Settings gear
      public static let settings = "gearshape"

      /// Settings gear filled
      public static let settingsFill = "gearshape.fill"

      /// Search
      public static let search = "magnifyingglass"

      /// Filter
      public static let filter = "line.3.horizontal.decrease"
    }

    /// Icons representing different entity types
    public enum Entity {
      /// Task item
      public static let task = "checkmark.square"

      /// Task item filled
      public static let taskFill = "checkmark.square.fill"

      /// Calendar event
      public static let activity = "calendar"

      /// Calendar event filled
      public static let activityFill = "calendar.circle.fill"

      /// Property/house icon
      public static let listing = "house"

      /// Property/house icon filled
      public static let listingFill = "house.fill"

      /// Map pin location
      public static let property = "mappin.and.ellipse"

      /// Map pin location filled
      public static let propertyFill = "mappin.and.ellipse.fill"

      /// Note item
      public static let note = "note.text"

      /// Subtask item
      public static let subtask = "checklist"

      /// Person icon
      public static let user = "person.circle"

      /// Person icon filled
      public static let userFill = "person.circle.fill"

      /// Team/Group
      public static let team = "person.2"

      /// Team filled
      public static let teamFill = "person.2.fill"

      /// Real estate agent
      public static let realtor = "person.text.rectangle"
    }

    /// Icons for specific activity types
    public enum ActivityType {
      /// Phone call
      public static let call = "phone"

      /// Phone call filled
      public static let callFill = "phone.fill"

      /// Email
      public static let email = "envelope"

      /// Email filled
      public static let emailFill = "envelope.fill"

      /// Meeting
      public static let meeting = "person.2.circle"

      /// Show property
      public static let showProperty = "house.and.flag"

      /// Follow up
      public static let followUp = "arrow.uturn.backward.circle"

      /// Other/General
      public static let other = "square.grid.2x2"
    }

    /// Icons for notifications and alerts
    public enum Alert {
      /// Warning triangle
      public static let warning = "exclamationmark.triangle"

      /// Warning filled
      public static let warningFill = "exclamationmark.triangle.fill"

      /// Error/Critical
      public static let error = "xmark.octagon"

      /// Error filled
      public static let errorFill = "xmark.octagon.fill"

      /// Info
      public static let info = "info.circle"

      /// Info filled
      public static let infoFill = "info.circle.fill"

      /// Success checkmark
      public static let success = "checkmark.circle"

      /// Success filled
      public static let successFill = "checkmark.circle.fill"

      /// Bell notification
      public static let notification = "bell"

      /// Bell notification filled
      public static let notificationFill = "bell.fill"

      /// Bell with badge
      public static let notificationBadge = "bell.badge"
    }

    /// Icons for user roles/audiences
    public enum RoleIcons {
      /// Admin indicator
      public static let admin = "a.circle"

      /// Admin indicator filled
      public static let adminFill = "a.circle.fill"

      /// Marketing indicator
      public static let marketing = "m.circle"

      /// Marketing indicator filled
      public static let marketingFill = "m.circle.fill"
    }

    /// Icons for lifecycle stages
    public enum Stage {
      public static let pending = "clock"
      public static let workingOn = "hammer"
      public static let live = "checkmark.seal"
      public static let sold = "dollarsign.circle"
      public static let reList = "arrow.clockwise"
      public static let done = "checkmark.circle"
    }

    /// Icons for time and date related elements
    public enum Time {
      /// Clock
      public static let clock = "clock"

      /// Clock filled
      public static let clockFill = "clock.fill"

      /// Calendar
      public static let calendar = "calendar"

      /// Calendar with clock (scheduled)
      public static let scheduled = "calendar.badge.clock"

      /// Overdue (clock with exclamation)
      public static let overdue = "clock.badge.exclamationmark"

      /// Timer
      public static let timer = "timer"
    }

    /// Simple filled circle for priority dots
    public static let priorityDot = "circle.fill"
  }
}
