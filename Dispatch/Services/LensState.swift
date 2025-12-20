//
//  LensState.swift
//  Dispatch
//
//  Global state for audience and content filters
//

import Combine
import SwiftUI

/// Observable state for the global filter lens.
/// Manages both audience (All/Admin/Marketing) and content kind (All/Tasks/Activities) filters.
@MainActor
final class LensState: ObservableObject {
    /// Current screen for determining filter button visibility
    enum CurrentScreen {
        case tasks
        case activities
        case listings
        case listingDetail
        case menu
        case detail
        case other
    }

    /// Current audience filter
    @Published var audience: AudienceLens = .all

    /// Current content kind filter
    @Published var kind: ContentKind = .all

    /// Current screen context for filter button visibility
    @Published var currentScreen: CurrentScreen = .menu

    /// Filter button shows on TaskListView, ActivityListView, and ListingDetailView
    var showFilterButton: Bool {
        currentScreen == .tasks || currentScreen == .activities || currentScreen == .listingDetail
    }

    /// Returns true if any filter is active (not set to .all)
    var isFiltered: Bool {
        audience != .all || kind != .all
    }

    /// Cycles to the next audience lens
    func cycleAudience() {
        audience = audience.next
    }

    /// Resets all filters to their default (.all) state
    func reset() {
        audience = .all
        kind = .all
    }
}
