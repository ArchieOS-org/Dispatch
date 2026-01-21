//
//  iPadRootView.swift
//  Dispatch
//
//  Created for Dispatch Navigation Redesign
//

import SwiftUI
import SwiftData

#if os(iOS)
struct iPadRootView: View {

  // MARK: Internal

  var body: some View {
    NavigationSplitView {
      iPadSidebar(
        selection: selectedDestinationBinding,
        stageCounts: stageCounts,
        tabCounts: tabCounts,
        overdueCount: overdueCount,
        onSelectStage: { stage in
          appState.dispatch(.userSelectedDestination(.stage(stage)))
        }
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 400)
    } detail: {
      ZStack(alignment: .top) {
        // Main Content Area
        NavigationStack(path: pathBinding) {
          rootView(for: appState.router.selectedDestination)
            .appDestinations() // Attach central registry
            .toolbar(.hidden, for: .navigationBar) // Hide native navbar to use FloatingToolbar
        }
        
        // Floating Chrome
        FloatingToolbar(title: navigationTitle) {
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    appState.dispatch(.openSearch(initialText: ""))
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.Text.primary)
                }
                
                Button {
                    appState.dispatch(.newItem)
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.Text.primary)
                }
            }
        }
      }
    }
  }

  // MARK: Private
  
  // swiftlint:disable:next force_unwrapping
  private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var appState: AppState
  @Environment(\.modelContext) private var modelContext

  @Query private var users: [User]
  @Query private var allListings: [Listing]
  @Query private var allTasksRaw: [TaskItem]
  @Query private var allActivitiesRaw: [Activity]
  @Query private var allPropertiesRaw: [Property]
  @Query private var allRealtorsRaw: [User]

  private var currentUserId: UUID { syncManager.currentUserID ?? Self.unauthenticatedUserId }
  
  // -- Count Logic (Duplicated from MacRootView) --
  
  private var workspaceTasks: [TaskItem] {
    guard let uid = syncManager.currentUserID else { return [] }
    return allTasksRaw.filter { $0.assigneeUserIds.contains(uid) && $0.status != .deleted }
  }

  private var workspaceActivities: [Activity] {
    guard let uid = syncManager.currentUserID else { return [] }
    return allActivitiesRaw.filter { $0.assigneeUserIds.contains(uid) && $0.status != .deleted }
  }

  private var activeProperties: [Property] { allPropertiesRaw.filter { $0.deletedAt == nil } }
  private var activeListings: [Listing] { allListings.filter { $0.status != .deleted } }
  private var activeRealtors: [User] { allRealtorsRaw.filter { $0.userType == .realtor } }
  private var stageCounts: [ListingStage: Int] { activeListings.stageCounts() }
  
  private var overdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }
  
  private var tabCounts: [AppTab: Int] {
    [
      .workspace: workspaceTasks.count + workspaceActivities.count,
      .properties: activeProperties.count,
      .listings: activeListings.count,
      .realtors: activeRealtors.count
    ]
  }
  
  // -- Bindings --
  
  private var selectedDestinationBinding: Binding<SidebarDestination> {
    Binding(
      get: { appState.router.selectedDestination },
      set: { newValue in
        Task { @MainActor in
          appState.dispatch(.userSelectedDestination(newValue))
        }
      }
    )
  }
  
  private var pathBinding: Binding<[AppRoute]> {
    Binding(
      get: { appState.router.paths[appState.router.selectedDestination] ?? [] },
      set: { newValue in
        let destination = appState.router.selectedDestination
        Task { @MainActor in
          appState.dispatch(.setPath(newValue, for: destination))
        }
      }
    )
  }
  
  // -- View Factory --
  
  private var navigationTitle: String {
    switch appState.router.selectedDestination {
    case .tab(let tab):
        return tab.rawValue.capitalized
    case .stage(let stage):
        return stage.rawValue.capitalized
    }
  }
  
  @ViewBuilder
  private func rootView(for destination: SidebarDestination) -> some View {
    switch destination {
    case .tab(let tab):
      switch tab {
      case .workspace: MyWorkspaceView()
      case .properties: PropertiesListView()
      case .listings: ListingListView()
      case .realtors: RealtorsListView()
      case .settings: SettingsView()
      case .search: MyWorkspaceView() // Fallback
      }
    case .stage(let stage):
      StagedListingsView(stage: stage)
    }
  }

}
#endif
