//
//  iPadContentView.swift
//  Dispatch
//
//  iPad navigation using native NavigationSplitView and .toolbar.
//  Target: ~50 LOC. No custom wrappers.
//

#if os(iOS)
import SwiftUI

/// iPad navigation container using native SwiftUI patterns.
struct iPadContentView: View {

  // MARK: Internal

  let stageCounts: [ListingStage: Int]
  let workspaceTasks: [TaskItem]
  let workspaceActivities: [Activity]
  let activeListings: [Listing]
  let activeProperties: [Property]
  let activeRealtors: [User]
  let pathBindingProvider: (SidebarDestination) -> Binding<[AppRoute]>

  /// Global Quick Find text state
  @Binding var quickFindText: String

  /// Instant search ViewModel
  let searchViewModel: SearchViewModel

  /// Callback when search result is selected
  let onSelectSearchResult: (SearchResult) -> Void

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      UnifiedSidebarContent(
        stageCounts: stageCounts,
        tabCounts: tabCounts,
        overdueCount: overdueCount,
        selection: appState.sidebarSelectionBinding,
        onSelectStage: { stage in
          appState.dispatch(.setSelectedDestination(.stage(stage)))
        }
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .bottomBar) {
          FilterMenu(audience: $appState.lensState.audience)
          Spacer()
        }
      }
    } detail: {
      NavigationStack(path: pathBindingProvider(appState.router.selectedDestination)) {
        destinationRootView(for: appState.router.selectedDestination)
          .appDestinations()
      }
      .id(appState.router.selectedDestination)
    }
    .navigationSplitViewStyle(.balanced)
    // FAB Menu overlay for quick entry - uses .overlay to ensure proper sizing
    .overlay(alignment: .bottomTrailing) {
      if appState.overlayState == .none, !shouldHideFAB {
        FABMenu { option in
          switch option {
          case .listing:
            appState.sheetState = .addListing
          case .task:
            appState.sheetState = .quickEntry(type: .task)
          case .activity:
            appState.sheetState = .quickEntry(type: .activity)
          }
        }
        .padding(.trailing, DS.Spacing.floatingButtonMargin)
        .padding(.bottom, DS.Spacing.floatingButtonBottomInset)
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
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState
  @Environment(\.globalButtonsHidden) private var environmentHidden
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  /// Single source of truth for FAB visibility.
  /// Combines environment-based hiding (SettingsScreen) with state-based hiding (keyboard, modals).
  private var shouldHideFAB: Bool {
    environmentHidden || overlayState.isOverlayHidden
  }

  private var tabCounts: [AppTab: Int] {
    [
      .workspace: workspaceTasks.count + workspaceActivities.count,
      .properties: activeProperties.count,
      .listings: activeListings.count,
      .realtors: activeRealtors.count
    ]
  }

  private var overdueCount: Int {
    let today = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count { ($0.dueDate ?? .distantFuture) < today }
      + workspaceActivities.count { ($0.dueDate ?? .distantFuture) < today }
  }

  @ViewBuilder
  private func destinationRootView(for destination: SidebarDestination) -> some View {
    switch destination {
    case .tab(let tab):
      switch tab {
      case .workspace: MyWorkspaceView()
      case .properties: PropertiesListView()
      case .listings: ListingListView()
      case .realtors: RealtorsListView()
      case .settings: SettingsView()
      case .search: MyWorkspaceView()
      }

    case .stage(let stage): StagedListingsView(stage: stage)
    }
  }
}
#endif
