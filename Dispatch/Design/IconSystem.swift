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
    }

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
    }

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

    /// Icons for navigation elements
    enum Navigation {
      /// Back arrow
      static let back = "chevron.left"

      /// Up arrow
      static let up = "chevron.up"

      /// Down arrow
      static let down = "chevron.down"

      /// Forward arrow
      static let forward = "chevron.right"

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
      static let filter = "line.3.horizontal.decrease"
    }

    /// Icons representing different entity types
    enum Entity {
      /// Task item
      static let task = "checkmark.square"

      /// Task item filled
      static let taskFill = "checkmark.square.fill"

      /// Calendar event
      static let activity = "calendar"

      /// Calendar event filled
      static let activityFill = "calendar.circle.fill"

      /// Property/house icon
      static let listing = "house"

      /// Property/house icon filled
      static let listingFill = "house.fill"

      /// Map pin location
      static let property = "mappin.and.ellipse"

      /// Map pin location filled
      static let propertyFill = "mappin.and.ellipse.fill"

      /// Note item
      static let note = "note.text"

      /// Subtask item
      static let subtask = "checklist"

      /// Person icon
      static let user = "person.circle"

      /// Person icon filled
      static let userFill = "person.circle.fill"

      /// Team/Group
      static let team = "person.2"

      /// Team filled
      static let teamFill = "person.2.fill"

      /// Real estate agent
      static let realtor = "person.text.rectangle"
    }

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

    /// Icons for user roles/audiences
    enum RoleIcons {
      /// Admin indicator
      static let admin = "a.circle"

      /// Admin indicator filled
      static let adminFill = "a.circle.fill"

      /// Marketing indicator
      static let marketing = "m.circle"

      /// Marketing indicator filled
      static let marketingFill = "m.circle.fill"
    }

    /// Icons for lifecycle stages
    enum Stage {
      static let pending = "clock"
      static let workingOn = "hammer"
      static let live = "checkmark.seal"
      static let sold = "dollarsign.circle"
      static let reList = "arrow.clockwise"
      static let done = "checkmark.circle"
    }

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

    /// Simple filled circle for priority dots
    static let priorityDot = "circle.fill"

  }
}
