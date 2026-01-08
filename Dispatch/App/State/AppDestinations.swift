//
//  AppDestinations.swift
//  Dispatch
//
//  Central registry for all navigation destinations in the app.
//  Implementation of "One Boss" Phase 3: Consolidate Destinations.
//

import SwiftUI

// MARK: - AppDestinationsModifier

/// Central registry of all navigation destinations.
/// Attached to the Root Stack of each "Captain" (AppShell).
struct AppDestinationsModifier: ViewModifier {

  // MARK: Internal

  func body(content: Content) -> some View {
    content
      // MARK: - Work Items (Tasks/Activities)
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
          onAddSubtask: actions.onAddSubtask,
        )
      }
      // MARK: - Routes (Type-safe navigation)
      .navigationDestination(for: Route.self) { route in
        routeDestination(for: route)
      }
      // MARK: - Core Entities
      .navigationDestination(for: Listing.self) { listing in
        ListingDetailView(listing: listing, userLookup: actions.userLookup)
      }
      .navigationDestination(for: Property.self) { property in
        PropertyDetailView(property: property, userLookup: actions.userLookup)
      }
      .navigationDestination(for: User.self) { user in
        RealtorProfileView(user: user)
      }
      // MARK: - iPhone Menu Navigation
      .navigationDestination(for: AppTab.self) { tab in
        menuDestination(for: tab)
      }
      // MARK: - Settings Navigation
      .navigationDestination(for: SettingsSection.self) { section in
        settingsDestination(for: section)
      }
      .navigationDestination(for: ListingTypeDefinition.self) { listingType in
        ListingTypeDetailView(listingType: listingType)
      }
      // PROBE: Signal that registry is active
      .environment(\.destinationsAttached, true)
  }

  // MARK: Private

  @EnvironmentObject private var actions: WorkItemActions

  @ViewBuilder
  private func menuDestination(for tab: AppTab) -> some View {
    switch tab {
    case .workspace:
      MyWorkspaceView()
    case .properties:
      PropertiesListView()
    case .listings:
      ListingListView()
    case .realtors:
      RealtorsListView()
    case .settings:
      SettingsView()
    case .search:
      EmptyView() // Search is overlay, not push destination
    }
  }

  @ViewBuilder
  private func settingsDestination(for section: SettingsSection) -> some View {
    switch section {
    case .listingTypes:
      ListingTypeListView()
    }
  }

  @ViewBuilder
  private func routeDestination(for route: Route) -> some View {
    switch route {
    case .stagedListings(let stage):
      StagedListingsView(stage: stage)
    }
  }
}

extension EnvironmentValues {
  @Entry var destinationsAttached = false
}

extension View {
  /// Attaches the central navigation destination registry to a NavigationStack.
  /// Must be called on the *content* of a NavigationStack, not the stack itself.
  func appDestinations() -> some View {
    modifier(AppDestinationsModifier())
  }
}
