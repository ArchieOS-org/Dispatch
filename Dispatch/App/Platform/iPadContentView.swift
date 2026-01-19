//
//  iPadContentView.swift
//  Dispatch
//
//  iPad-specific navigation view extracted from ContentView.
//  Uses NavigationSplitView with UnifiedSidebarContent for consistent
//  sidebar UI shared with macOS (80%+ code sharing).
//

#if os(iOS)
import SwiftUI

/// iPad navigation container with NavigationSplitView using unified sidebar.
/// Extracted from ContentView to reduce complexity and enable platform-specific optimizations.
struct iPadContentView: View {

  // MARK: Internal

  /// Binding for destination-based tab selection
  let selectedDestinationBinding: Binding<SidebarDestination>

  /// Stage counts for sidebar header
  let stageCounts: [ListingStage: Int]

  /// Workspace tasks for badge counts
  let workspaceTasks: [TaskItem]

  /// Workspace activities for badge counts
  let workspaceActivities: [Activity]

  /// Active listings for badge counts
  let activeListings: [Listing]

  /// Active properties for badge counts
  let activeProperties: [Property]

  /// Active realtors for badge counts
  let activeRealtors: [User]

  /// Function to create path binding for a destination
  let pathBindingProvider: (SidebarDestination) -> Binding<[AppRoute]>

  var body: some View {
    ZStack {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        // Unified sidebar content (shared with macOS)
        UnifiedSidebarContent(
          stageCounts: stageCounts,
          tabCounts: iPadTabCounts,
          overdueCount: sidebarOverdueCount,
          selection: sidebarSelectionBinding,
          onSelectStage: { stage in
            appState.dispatch(.setSelectedDestination(.stage(stage)))
          }
        )
        .navigationTitle("Dispatch")
        .navigationBarTitleDisplayMode(.inline)
      } detail: {
        // Detail view based on selected destination
        NavigationStack(path: pathBindingProvider(appState.router.selectedDestination)) {
          destinationRootView(for: appState.router.selectedDestination)
            .appDestinations()
        }
      }
      .navigationSplitViewStyle(.balanced)

      // FAB overlay for iPad (kept for quick entry)
      iPadFABOverlay
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState

  /// Controls sidebar column visibility
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  /// Overdue count for workspace badge
  private var sidebarOverdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }

  /// Tab counts for UnifiedSidebarContent.
  /// Note: iPad uses NavigationSplitView with sidebar, so tab badges are replaced by
  /// inline counts in SidebarMenuRow (e.g., "Properties 8"). The old TabView badgeCount(for:)
  /// approach only applies to iPhone's tab bar, which isn't used on iPad.
  private var iPadTabCounts: [AppTab: Int] {
    [
      .workspace: workspaceTasks.count + workspaceActivities.count,
      .properties: activeProperties.count,
      .listings: activeListings.count,
      .realtors: activeRealtors.count
    ]
  }

  /// Computed binding for List(selection:) that bridges non-optional AppState to optional List API.
  private var sidebarSelectionBinding: Binding<SidebarDestination?> {
    Binding(
      get: {
        appState.router.selectedDestination.isStage
          ? nil
          : appState.router.selectedDestination
      },
      set: { newValue in
        guard let dest = newValue, dest != appState.router.selectedDestination else { return }
        // Defer state change to avoid "Publishing changes from within view updates" error.
        Task { @MainActor in
          appState.dispatch(.userSelectedDestination(dest))
        }
      }
    )
  }

  /// iPad floating FAB overlay with proper safe area handling
  @ViewBuilder
  private var iPadFABOverlay: some View {
    if appState.overlayState == .none {
      // ZStack so spacer doesn't block FAB taps
      ZStack(alignment: .bottomTrailing) {
        // Spacer layer - pass through all touches
        Color.clear.allowsHitTesting(false)

        // FAB - receives taps normally
        FloatingActionButton {
          appState.sheetState = .quickEntry(type: nil)
        }
        .padding(.trailing, DS.Spacing.floatingButtonMargin)
        .safeAreaPadding(.bottom, DS.Spacing.floatingButtonBottomInset)
      }
    }
  }

  /// Root view for any destination (tab or stage) - iPad
  @ViewBuilder
  private func destinationRootView(for destination: SidebarDestination) -> some View {
    switch destination {
    case .tab(let tab):
      tabRootView(for: tab)
    case .stage(let stage):
      StagedListingsView(stage: stage)
    }
  }

  /// Root view for each tab in iPad.
  @ViewBuilder
  private func tabRootView(for tab: AppTab) -> some View {
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
      MyWorkspaceView() // Search is overlay, shouldn't be a tab destination
    }
  }

}
#endif
