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

  /// Active listings for sheet
  let activeListings: [Listing]

  /// All users for sheet
  let users: [User]

  /// Current user ID for sheets
  let currentUserId: UUID

  /// Instant search ViewModel
  let searchViewModel: SearchViewModel

  /// Callback when search result is selected
  let onSelectSearchResult: (SearchResult) -> Void

  /// Callback to request sync after save
  let onRequestSync: () -> Void

  var body: some View {
    // ZStack allows GlobalFloatingButtons to persist during NavigationStack transitions.
    // The overlay is a sibling to NavigationStack, not a descendant of the root view,
    // so it remains visible when navigating to destination views.
    ZStack(alignment: .bottom) {
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

      // GlobalFloatingButtons uses AppOverlayState (EnvironmentObject) for visibility.
      // SettingsScreen calls overlayState.hide(.settingsScreen) to hide during settings.
      // Only show when no search/settings overlay is active.
      if appState.overlayState == .none {
        GlobalFloatingButtons()
      }
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
          searchViewModel: searchViewModel,
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
    case .quickEntry(let type, let preselectedListing):
      QuickEntrySheet(
        defaultItemType: type ?? .task,
        currentUserId: currentUserId,
        listings: activeListings,
        availableUsers: users,
        preselectedListing: preselectedListing,
        onSave: { onRequestSync() }
      )
      .id(state.id) // Force view recreation when state changes (fixes pre-selection timing)

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
