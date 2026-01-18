//
//  iPhoneContentView.swift
//  Dispatch
//
//  iPhone-specific navigation view extracted from ContentView.
//  Uses Things 3-style MenuPageView with push navigation.
//

#if os(iOS)
import SwiftUI

/// iPhone navigation container with Things 3-style menu and single NavigationStack.
/// Extracted from ContentView to reduce complexity and enable platform-specific optimizations.
struct iPhoneContentView: View {

  // MARK: Internal

  /// Binding to iPhone's single navigation path
  let phonePathBinding: Binding<[AppRoute]>

  /// Global Quick Find text state
  @Binding var quickFindText: String

  /// Stage counts for MenuPageView
  let stageCounts: [ListingStage: Int]

  /// Tab counts for MenuPageView
  let phoneTabCounts: [AppTab: Int]

  /// Overdue count for MenuPageView
  let overdueCount: Int

  /// Active tasks for search overlay
  let activeTasks: [TaskItem]

  /// Active activities for search overlay
  let activeActivities: [Activity]

  /// Active listings for search overlay
  let activeListings: [Listing]

  /// All users for sheet
  let users: [User]

  /// Current user ID for sheets
  let currentUserId: UUID

  /// Callback when search result is selected
  let onSelectSearchResult: (SearchResult) -> Void

  /// Callback to request sync after save
  let onRequestSync: () -> Void

  var body: some View {
    ZStack {
      NavigationStack(path: phonePathBinding) {
        PullToSearchHost {
          MenuPageView(
            stageCounts: stageCounts,
            tabCounts: phoneTabCounts,
            overdueCount: overdueCount
          )
        }
        .appDestinations()
      }
      .overlay {
        // Search overlay - Conditional rendering per SwiftUI best practices
        // View is added/removed from hierarchy cleanly, enabling proper focus management
        // via defaultFocus modifier (no delays needed)
        //
        // Data is passed from ContentView's @Query properties to avoid duplicate queries.
        if appState.overlayState.isSearch {
          SearchOverlay(
            isPresented: Binding(
              get: { appState.overlayState.isSearch },
              set: { newValue in
                // Defer state change to avoid "Publishing changes from within view updates" warning.
                // Task schedules the dispatch for the next run loop iteration.
                Task { @MainActor in
                  if !newValue {
                    appState.overlayState = .none
                  }
                }
              }
            ),
            searchText: $quickFindText,
            tasks: activeTasks,
            activities: activeActivities,
            listings: activeListings,
            onSelectResult: { result in
              onSelectSearchResult(result)
            }
          )
          .transition(.opacity.animation(.easeOut(duration: 0.2)))
        }
      }
      .onChange(of: appState.overlayState) { _, newState in
        // Update quickFindText when search opens with initial text
        if case .search(let initialText) = newState {
          quickFindText = initialText ?? ""
        }
      }

      // Persistent floating buttons
      // Helper to hide buttons when overlay is active (One Boss)
      if appState.overlayState == .none {
        GlobalFloatingButtons()
      }
    }
    .onAppear {
      // Attach KeyboardObserver to track keyboard visibility
      keyboardObserver.attach(to: overlayState)
    }
    // iOS Sheet Handling now driven by AppState
    .sheet(item: appState.sheetBinding) { state in
      sheetContent(for: state)
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var overlayState: AppOverlayState
  @StateObject private var keyboardObserver = KeyboardObserver()

  @ViewBuilder
  private func sheetContent(for state: AppState.SheetState) -> some View {
    switch state {
    case .quickEntry(let type):
      QuickEntrySheet(
        defaultItemType: type ?? .task,
        currentUserId: currentUserId,
        listings: activeListings,
        availableUsers: users,
        onSave: { onRequestSync() }
      )

    case .addListing:
      AddListingSheet(
        currentUserId: currentUserId,
        onSave: { onRequestSync() }
      )

    case .addRealtor:
      EditRealtorSheet()

    case .none:
      EmptyView()
    }
  }
}
#endif
