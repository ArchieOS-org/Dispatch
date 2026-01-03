//
//  AppDestinations.swift
//  Dispatch
//
//  Central registry for all navigation destinations in the app.
//  Implementation of "One Boss" Phase 3: Consolidate Destinations.
//

import SwiftUI

/// Central registry of all navigation destinations.
/// Attached to the Root Stack of each "Captain" (AppShell).
struct AppDestinationsModifier: ViewModifier {
    @EnvironmentObject private var actions: WorkItemActions

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
                    onAddSubtask: actions.onAddSubtask
                )
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
            .navigationDestination(for: MenuSection.self) { section in
                menuDestination(for: section)
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
    
    @ViewBuilder
    private func menuDestination(for section: MenuSection) -> some View {
        switch section {
        case .myWorkspace:
            MyWorkspaceView()
        case .properties:
            PropertiesListView()
        case .listings:
            ListingListView()
        case .realtors:
            RealtorsListView()
        case .settings:
            SettingsView()
        }
    }
    
    @ViewBuilder
    private func settingsDestination(for section: SettingsSection) -> some View {
        switch section {
        case .listingTypes:
            ListingTypeListView()
        }
    }
}

// MARK: - Debug Probe
private struct DestinationsAttachedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var destinationsAttached: Bool {
        get { self[DestinationsAttachedKey.self] }
        set { self[DestinationsAttachedKey.self] = newValue }
    }
}

extension View {
    /// Attaches the central navigation destination registry to a NavigationStack.
    /// Must be called on the *content* of a NavigationStack, not the stack itself.
    func appDestinations() -> some View {
        modifier(AppDestinationsModifier())
    }
}
