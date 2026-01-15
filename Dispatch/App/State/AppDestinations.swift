//
//  AppDestinations.swift
//  Dispatch
//
//  Central registry for all navigation destinations in the app.
//  Implementation of "One Boss" Phase 3: Consolidate Destinations.
//
//  All navigation now uses AppRoute (ID-based) to prevent crashes
//  when SwiftData's ModelContext is reset during sync operations.
//

import SwiftUI

// MARK: - AppDestinationsModifier

/// Central registry of all navigation destinations.
/// Attached to the Root Stack of each "Captain" (AppShell).
///
/// **Important:** All entity navigation uses AppRoute with UUIDs.
/// Model-based destinations have been removed to prevent SwiftData crashes.
struct AppDestinationsModifier: ViewModifier {

  // MARK: Internal

  func body(content: Content) -> some View {
    content
      // MARK: - All Routes (ID-based) - SINGLE DESTINATION
      .navigationDestination(for: AppRoute.self) { route in
        // Note: .tint() is NOT applied here because it would wrap the entire destination
        // including navigation modifiers, which causes title color issues during
        // interactive back gesture cancellation. Tint is applied at content level
        // by StandardScreen.innerContent or individual views.
        routeDestination(for: route)
      }
      // PROBE: Signal that registry is active
      .environment(\.destinationsAttached, true)
  }

  // MARK: Private

  @EnvironmentObject private var actions: WorkItemActions

  @ViewBuilder
  private func routeDestination(for route: AppRoute) -> some View {
    switch route {
    // Entity resolvers (ID-based)
    case .realtor(let id):
      RealtorResolver(id: id)

    case .listing(let id):
      ListingResolver(id: id)

    case .property(let id):
      PropertyResolver(id: id)

    case .listingType(let id):
      ListingTypeResolver(id: id)

    // Absorbed types (passthrough to existing views)
    case .workItem(let ref):
      WorkItemResolverView(
        ref: ref,
        currentUserId: actions.currentUserId,
        userLookup: actions.userLookupDict,
        availableUsers: actions.availableUsers,
        onComplete: actions.onComplete,
        onAssigneesChanged: actions.onAssigneesChanged,
        onEditNote: nil,
        onDeleteNote: actions.onDeleteNote,
        onAddNote: actions.onAddNote
      )

    case .settings(let section):
      settingsDestination(for: section)

    case .stagedListings(let stage):
      StagedListingsView(stage: stage)

    // Tab destinations (iPhone push navigation from menu)
    case .workspace:
      MyWorkspaceView()

    case .propertiesList:
      PropertiesListView()

    case .listingsList:
      ListingListView()

    case .realtorsList:
      RealtorsListView()

    case .settingsRoot:
      SettingsView()

    case .descriptionGenerator(let listingId):
      DescriptionGeneratorView(preselectedListingId: listingId)

    case .profile:
      ProfilePageView()
    }
  }

  @ViewBuilder
  private func settingsDestination(for section: SettingsSection) -> some View {
    switch section {
    case .listingTypes:
      ListingTypeListView()
    case .listingDraftDemo:
      ListingDraftDemoView()
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
