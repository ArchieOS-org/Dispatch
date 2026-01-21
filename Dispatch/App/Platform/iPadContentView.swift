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
  let users: [User]
  let currentUserId: UUID
  let pathBindingProvider: (SidebarDestination) -> Binding<[AppRoute]>

  /// Callback to request sync after save
  let onRequestSync: () -> Void

  var body: some View {
    ZStack {
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

      // FAB overlay for quick entry
      if appState.overlayState == .none {
        ZStack(alignment: .bottomTrailing) {
          Color.clear.allowsHitTesting(false)
          FloatingActionButton { appState.sheetState = .quickEntry(type: nil) }
            .padding(.trailing, DS.Spacing.floatingButtonMargin)
            .safeAreaPadding(.bottom, DS.Spacing.floatingButtonBottomInset)
        }
      }
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
