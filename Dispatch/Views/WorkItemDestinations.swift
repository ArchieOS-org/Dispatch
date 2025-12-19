//
//  WorkItemDestinations.swift
//  Dispatch
//
//  Shared navigation destinations modifier for WorkItem navigation.
//  Reads callbacks from WorkItemActions environment object.
//

import SwiftUI

extension View {
    /// Applies shared navigation destinations for WorkItem and Listing navigation.
    /// Must be called **inside** a NavigationStack (destinations must be inside the stack doing the pushing).
    ///
    /// Usage:
    /// ```
    /// NavigationStack {
    ///     MyListView()
    ///         .dispatchDestinations()
    /// }
    /// .environmentObject(actions)
    /// ```
    func dispatchDestinations() -> some View {
        modifier(DispatchDestinationsModifier())
    }
}

/// ViewModifier that provides shared navigation destinations.
/// Reads all state and callbacks from WorkItemActions environment object.
private struct DispatchDestinationsModifier: ViewModifier {
    @EnvironmentObject private var actions: WorkItemActions

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: WorkItemRef.self) { ref in
                WorkItemResolverView(
                    ref: ref,
                    currentUserId: actions.currentUserId,
                    userLookup: actions.userLookup,
                    onComplete: actions.onComplete,
                    onClaim: actions.onClaim,
                    onRelease: actions.onRelease,
                    onEditNote: nil,
                    onDeleteNote: actions.onDeleteNote,
                    onAddNote: actions.onAddNote,
                    onToggleSubtask: actions.onToggleSubtask,
                    onDeleteSubtask: actions.onDeleteSubtask,
                    onAddSubtask: actions.onAddSubtask
                )
            }
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing, userLookup: actions.userLookup)
            }
            .navigationDestination(for: MenuSection.self) { section in
                menuDestination(for: section)
            }
    }

    @ViewBuilder
    private func menuDestination(for section: MenuSection) -> some View {
        switch section {
        case .tasks:
            TaskListView(embedInNavigationStack: false)
        case .activities:
            ActivityListView(embedInNavigationStack: false)
        case .listings:
            ListingListView(embedInNavigationStack: false)
        }
    }
}
