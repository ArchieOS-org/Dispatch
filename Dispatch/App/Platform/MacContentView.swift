//
//  MacContentView.swift
//  Dispatch
//
//  macOS navigation using native NavigationSplitView and .toolbar.
//  Target: ~80 LOC. No custom floating toolbars or window chrome hacks.
//

#if os(macOS)
import SwiftData
import SwiftUI

/// macOS navigation container using native SwiftUI patterns.
struct MacContentView: View {

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
  let onSelectSearchResult: (SearchResult) -> Void
  let onRequestSync: () -> Void

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
      .navigationTitle("Dispatch")
    } detail: {
      NavigationStack(path: pathBindingProvider(appState.router.selectedDestination)) {
        destinationRootView(for: appState.router.selectedDestination)
          .appDestinations()
      }
      .toolbar(removing: .title)
    }
    .navigationSplitViewStyle(.automatic)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        FilterMenu(audience: $appState.lensState.audience)
        Button { handleNew() } label: { Image(systemName: "plus") }
          .help("New Item")
          .keyboardShortcut("n", modifiers: .command)
          .accessibilityLabel("New item")
          .accessibilityHint("Creates a new task, activity, or listing based on current context")
        if supportsMultipleWindows {
          Button { openWindow(id: "main") } label: { Image(systemName: "square.on.square") }
            .help("New Window")
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .accessibilityLabel("New window")
            .accessibilityHint("Opens a new Dispatch window")
        }
        Button { windowUIState.openSearch(initialText: nil) } label: { Image(systemName: "magnifyingglass") }
          .help("Search")
          .keyboardShortcut("f", modifiers: .command)
          .accessibilityLabel("Search")
          .accessibilityHint("Opens global search overlay")
      }
    }
    .overlay(alignment: .top) { quickFindOverlay }
    .sheet(item: sheetBinding) { sheetContent(for: $0) }
    .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in
      if controlActiveState == .key { windowUIState.openSearch(initialText: nil) }
    }
    .focusedValue(\.columnVisibility, $columnVisibility)
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager
  @Environment(WindowUIState.self) private var windowUIState
  @Environment(\.openWindow) private var openWindow
  @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
  @Environment(\.controlActiveState) private var controlActiveState

  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var quickFindText = ""

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

  private var sheetBinding: Binding<AppState.SheetState?> {
    Binding(
      get: { appState.sheetState == .none ? nil : appState.sheetState },
      set: { newValue in Task { @MainActor in appState.sheetState = newValue ?? .none } }
    )
  }

  @ViewBuilder
  private var quickFindOverlay: some View {
    if case .search(let initialText) = windowUIState.overlayState {
      ZStack(alignment: .top) {
        Color.black.opacity(0.1).ignoresSafeArea()
          .onTapGesture { windowUIState.closeOverlay() }
        NavigationPopover(
          searchText: $quickFindText,
          isPresented: Binding(get: { true }, set: { if !$0 { windowUIState.closeOverlay() } }),
          currentTab: appState.router.selectedTab,
          onNavigate: { appState.dispatch(.selectTab($0))
            windowUIState.closeOverlay()
          },
          onSelectResult: { onSelectSearchResult($0)
            windowUIState.closeOverlay()
          }
        )
        .padding(.top, DS.Spacing.xxxl * 3)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task(id: initialText) {
          if let text = initialText { try? await Task.sleep(for: .milliseconds(150))
            quickFindText = text
          }
        }
      }
      .zIndex(100)
    }
  }

  private func handleNew() {
    switch appState.router.selectedDestination {
    case .tab(.listings), .stage: appState.sheetState = .addListing
    case .tab(.realtors): appState.sheetState = .addRealtor
    default: appState.sheetState = .quickEntry(type: nil)
    }
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

  @ViewBuilder
  private func sheetContent(for state: AppState.SheetState) -> some View {
    switch state {
    case .quickEntry(let type):
      QuickEntrySheet(
        defaultItemType: type ?? .task,
        currentUserId: currentUserId,
        listings: activeListings,
        availableUsers: users,
        onSave: onRequestSync
      )

    case .addListing: AddListingSheet(currentUserId: currentUserId, onSave: onRequestSync)

    case .addRealtor: EditRealtorSheet()

    case .none: EmptyView()
    }
  }
}

#Preview {
  MacContentView(
    stageCounts: [:], workspaceTasks: [], workspaceActivities: [],
    activeListings: [], activeProperties: [], activeRealtors: [],
    users: [], currentUserId: UUID(), pathBindingProvider: { _ in .constant([]) },
    onSelectSearchResult: { _ in }, onRequestSync: { }
  )
  .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self, Property.self], inMemory: true)
  .environmentObject(AppState())
  .environmentObject(SyncManager())
  .environment(WindowUIState())
  .frame(width: 1100, height: 750)
}
#endif
