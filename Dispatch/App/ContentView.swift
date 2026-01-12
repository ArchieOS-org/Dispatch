//
//  ContentView.swift
//  Dispatch
//
//  Root navigation for the Dispatch app
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftData
import SwiftUI

/// Root view providing navigation between:
/// - Tasks: TaskListView with segmented filter and date sections
/// - Activities: ActivityListView with same structure
/// - Listings: ListingListView grouped by owner with search
///
/// Adaptive layout:
/// - iPhone: MenuPageView with Things 3-style cards, push navigation
/// - iPad Landscape/macOS: NavigationSplitView with sidebar
struct ContentView: View {

  // MARK: Internal

  var body: some View {
    bodyCore
      .environmentObject(workItemActions)
      // .environmentObject(searchManager) // Remvoved
      .environmentObject(appState.lensState)
    // .environmentObject(quickEntryState) // Removed
    // .environmentObject(overlayState) // Removed
    #if os(macOS)
      .background(KeyMonitorView { event in
        handleGlobalKeyDown(event)
      })
      .overlay(alignment: .top) {
        quickFindOverlay
      }
      .sheet(item: sheetStateBinding) { state in
        sheetContent(for: state)
      }
    #endif
  }

  // MARK: Private

  /// Sentinel UUID for unauthenticated state
  private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var appState: AppState // One Boss injection
  @Environment(\.modelContext) private var modelContext

  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// Device idiom detection for container selection (NOT size class).
  /// Using size class would flip iPad Slide Over/Split View into iPhone UI incorrectly.
  private var isPhone: Bool {
    UIDevice.current.userInterfaceIdiom == .phone
  }
  #endif

  @Query private var users: [User]
  @Query private var allListings: [Listing]
  @Query private var allTasksRaw: [TaskItem]
  @Query private var allActivitiesRaw: [Activity]
  @Query private var allPropertiesRaw: [Property]
  @Query private var allRealtorsRaw: [User]

  /// Centralized WorkItemActions environment object for shared navigation
  @StateObject private var workItemActions = WorkItemActions()

  #if os(macOS)
  /// Global Quick Find (Popover) State managed by AppState.overlayState
  @State private var quickFindText = ""
  /// Local sidebar selection synced via .onChange (avoids mutation during render)
  @State private var sidebarSelection: SidebarDestination? = nil
  #else
  /// Global Quick Find text state for iOS search overlay
  @State private var quickFindText = ""
  /// Local sidebar selection synced via .onChange (avoids mutation during render)
  @State private var sidebarSelection: SidebarDestination? = nil
  /// Controls stage picker sheet visibility (for tab-bar mode fallback)
  @State private var showStagePicker = false
  #endif
  // searchManager migrated to AppState
  // @StateObject private var searchManager = SearchPresentationManager()
  // Local nav state removed - deferring to AppState.router (One Boss)

  // QuickEntryState removed - migrated to AppState
  @StateObject private var overlayState = AppOverlayState()
  @StateObject private var keyboardObserver = KeyboardObserver()

  /// Local Tab state removed - using AppState.router.selectedTab (One Boss)
  private var selectedTab: AppTab {
    appState.router.selectedTab
  }

  // MARK: - Navigation Bindings (dispatch-driven)

  /// Binding for TabView selection that routes through dispatcher (legacy tab-based).
  /// Uses userSelectedTab which may pop-to-root on reselect.
  private var selectedTabBinding: Binding<AppTab> {
    Binding(
      get: { appState.router.selectedTab },
      set: { appState.dispatch(.userSelectedTab($0)) }
    )
  }

  /// Binding for TabView selection using SidebarDestination (destination-based).
  /// Uses userSelectedDestination which may pop-to-root on reselect.
  private var selectedDestinationBinding: Binding<SidebarDestination> {
    Binding(
      get: { appState.router.selectedDestination },
      set: { appState.dispatch(.userSelectedDestination($0)) }
    )
  }

  /// Binding for iPhone's single navigation path.
  private var phonePathBinding: Binding<[AppRoute]> {
    Binding(
      get: { appState.router.phonePath },
      set: { appState.dispatch(.setPhonePath($0)) }
    )
  }

  /// Pre-computed user lookup dictionary for O(1) access
  private var userCache: [UUID: User] {
    Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
  }

  /// Workspace tasks (claimed by current user and not deleted)
  private var workspaceTasks: [TaskItem] {
    guard let currentUserID = syncManager.currentUserID else { return [] }
    return allTasksRaw.filter { $0.claimedBy == currentUserID && $0.status != .deleted }
  }

  /// Workspace activities (claimed by current user and not deleted)
  private var workspaceActivities: [Activity] {
    guard let currentUserID = syncManager.currentUserID else { return [] }
    return allActivitiesRaw.filter { $0.claimedBy == currentUserID && $0.status != .deleted }
  }

  /// Active properties (not deleted)
  private var activeProperties: [Property] {
    allPropertiesRaw.filter { $0.deletedAt == nil }
  }

  /// Active listings (not deleted) for quick entry
  private var activeListings: [Listing] {
    allListings.filter { $0.status != .deleted }
  }

  /// Active realtors
  private var activeRealtors: [User] {
    allRealtorsRaw.filter { $0.userType == .realtor }
  }

  /// Stage counts computed once per render cycle from activeListings.
  private var stageCounts: [ListingStage: Int] {
    activeListings.stageCounts()
  }

  private var currentUserId: UUID {
    syncManager.currentUserID ?? Self.unauthenticatedUserId
  }

  // handleTabSelection removed - use appState.dispatch(.selectTab) directly

  #if os(macOS)
  private var toolbarContext: ToolbarContext {
    switch appState.router.selectedDestination {
    case .tab(let tab):
      switch tab {
      case .properties:
        .listingList // Properties uses listing-style toolbar
      case .listings:
        .listingList
      case .realtors:
        .realtorList
      case .settings:
        .taskList // Settings uses default toolbar
      case .workspace, .search:
        .taskList // Re-use task actions for now
      }

    case .stage:
      .listingList // All stage views use listing toolbar
    }
  }

  // MARK: - macOS Sidebar Helpers

  private func sidebarCount(for tab: AppTab) -> Int {
    switch tab {
    case .workspace: workspaceTasks.count + workspaceActivities.count
    case .properties: activeProperties.count
    case .listings: activeListings.count
    case .realtors: activeRealtors.count
    case .settings, .search: 0
    }
  }

  private var sidebarOverdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }

  /// macOS: Things 3-style resizable sidebar with native selection.
  /// Stage cards appear above the List (not inside it).
  /// Settings uses SettingsLink via SidebarDestinationList.
  private var sidebarNavigation: some View {
    ResizableSidebar {
      VStack(spacing: 0) {
        // Stage cards header (NOT in List - Reminders-style)
        // Tapping a stage card uses programmatic selection (never pops)
        StageCardsHeader(
          stageCounts: stageCounts,
          onSelectStage: { stage in
            appState.dispatch(.setSelectedDestination(.stage(stage)))
          }
        )

        // Destination list (tabs only - stages accessed via cards above)
        SidebarDestinationList(
          selection: $sidebarSelection,
          tabCounts: macTabCounts,
          overdueCount: sidebarOverdueCount
        )
        .onAppear {
          // Only sync tab selections to sidebar; stages are nil
          sidebarSelection = appState.router.selectedDestination.isStage
            ? nil
            : appState.router.selectedDestination
        }
        .onChange(of: sidebarSelection) { _, newValue in
          guard let dest = newValue, dest != appState.router.selectedDestination else { return }
          appState.dispatch(.userSelectedDestination(dest))
        }
        .onChange(of: appState.router.selectedDestination) { _, newValue in
          // Only sync tab selections to sidebar; stages show as nil (deselected)
          sidebarSelection = newValue.isStage ? nil : newValue
        }
      }
    } content: {
      NavigationStack(path: pathBinding(for: appState.router.selectedDestination)) {
        destinationRootView(for: appState.router.selectedDestination)
          .appDestinations()
      }
      .id(appState.router.stackIDs[appState.router.selectedDestination] ?? UUID())
      .toolbar {
        // FORCE the NSToolbar to exist at all times.
        // This prevents the window corner radius from flickering (Large vs Small) when navigating between views.
        ToolbarItem(placement: .primaryAction) {
          Color.clear.frame(width: 0, height: 0)
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        BottomToolbar(
          context: toolbarContext,
          audience: Binding(
            get: { appState.lensState.audience },
            set: { appState.lensState.audience = $0 }
          ),
          onNew: {
            switch appState.router.selectedDestination {
            case .tab(.listings), .stage:
              appState.sheetState = .addListing
            case .tab(.realtors):
              appState.sheetState = .addRealtor
            default:
              appState.sheetState = .quickEntry(type: nil)
            }
          },
          onSearch: {
            appState.dispatch(.openSearch(initialText: nil))
          }
        )
      }
    }
  }

  /// Root view for any destination (tab or stage) - macOS
  @ViewBuilder
  private func destinationRootView(for destination: SidebarDestination) -> some View {
    switch destination {
    case .tab(let tab):
      macTabRootView(for: tab)
    case .stage(let stage):
      StagedListingsView(stage: stage)
    }
  }

  /// macOS tab counts for SidebarTabList.
  private var macTabCounts: [AppTab: Int] {
    [
      .workspace: workspaceTasks.count + workspaceActivities.count,
      .properties: activeProperties.count,
      .listings: activeListings.count,
      .realtors: activeRealtors.count
    ]
  }

  /// macOS root view for selected tab.
  @ViewBuilder
  private func macTabRootView(for tab: AppTab) -> some View {
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
      MyWorkspaceView()
    }
  }
  #else
  /// iPad: TabView with sidebarAdaptable style (iOS 18+).
  /// Uses per-destination NavigationStacks with stable stack IDs.
  /// Stages are first-class destinations, hidden from tab bar via defaultVisibility.
  private var ipadTabViewNavigation: some View {
    ZStack {
      TabView(selection: selectedDestinationBinding) {
        // MARK: - Hidden stage tabs (programmatic selection only)
        // Not in a TabSection to avoid empty section header.
        // Hidden from both tabBar and sidebar; accessed via StageCardsHeader.
        ForEach(ListingStage.allCases, id: \.self) { stage in
          Tab(stage.displayName, systemImage: stage.icon, value: SidebarDestination.stage(stage)) {
            NavigationStack(path: pathBinding(for: .stage(stage))) {
              StagedListingsView(stage: stage)
                .appDestinations()
                .toolbar {
                  ToolbarItem(placement: .primaryAction) {
                    if appState.lensState.showFilterButton {
                      FilterMenu(audience: $appState.lensState.audience)
                    }
                  }
                }
            }
            .id(appState.router.stackIDs[.stage(stage)] ?? UUID())
          }
          .defaultVisibility(.hidden, for: .tabBar)
          .defaultVisibility(.hidden, for: .sidebar)
        }

        // MARK: - Main tabs section
        TabSection {
          ForEach(AppTab.mainTabs) { tab in
            Tab(tab.title, systemImage: tab.icon, value: SidebarDestination.tab(tab)) {
              NavigationStack(path: pathBinding(for: .tab(tab))) {
                tabRootView(for: tab)
                  .appDestinations()
                  .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                      if appState.lensState.showFilterButton {
                        FilterMenu(audience: $appState.lensState.audience)
                      }
                    }
                    // Stage picker button for tab-bar mode fallback
                    ToolbarItem(placement: .primaryAction) {
                      stagePickerButton
                    }
                  }
              }
              .id(appState.router.stackIDs[.tab(tab)] ?? UUID())
            }
            .badge(badgeCount(for: tab))
          }
        }

        // MARK: - Settings section (separate for visual grouping)
        TabSection {
          Tab("Settings", systemImage: "gearshape", value: SidebarDestination.tab(.settings)) {
            NavigationStack {
              SettingsView()
                .appDestinations()
            }
          }
        }
      }
      .tabViewStyle(.sidebarAdaptable)
      .tabViewSidebarHeader {
        // Stage cards header - tapping uses programmatic selection (never pops)
        StageCardsHeader(
          stageCounts: stageCounts,
          onSelectStage: { stage in
            appState.dispatch(.setSelectedDestination(.stage(stage)))
          }
        )
      }
      .sheet(isPresented: $showStagePicker) {
        stagePickerSheet
      }

      // FAB overlay for iPad
      iPadFABOverlay
    }
  }

  /// Toolbar button to open stage picker (fallback for tab-bar mode)
  @ViewBuilder
  private var stagePickerButton: some View {
    Button {
      showStagePicker = true
    } label: {
      Label("Stages", systemImage: "folder")
    }
  }

  /// Stage picker sheet for tab-bar mode fallback
  private var stagePickerSheet: some View {
    NavigationStack {
      List {
        ForEach(ListingStage.allCases, id: \.self) { stage in
          Button {
            showStagePicker = false
            appState.dispatch(.setSelectedDestination(.stage(stage)))
          } label: {
            Label {
              HStack {
                Text(stage.displayName)
                Spacer()
                if let stageCount = stageCounts[stage], stageCount > 0, stage != .done {
                  Text("\(stageCount)")
                    .foregroundStyle(.secondary)
                }
              }
            } icon: {
              Image(systemName: stage.icon)
                .foregroundStyle(stage.color)
            }
          }
          .foregroundStyle(.primary)
        }
      }
      .navigationTitle("Stages")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showStagePicker = false
          }
        }
      }
    }
    .presentationDetents([.medium])
  }

  /// Root view for each tab in iPad TabView.
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

  /// Badge count for iPad tab badges.
  private func badgeCount(for tab: AppTab) -> Int {
    switch tab {
    case .workspace:
      sidebarOverdueCount > 0 ? sidebarOverdueCount : 0
    case .listings:
      activeListings.count
    case .properties:
      activeProperties.count
    case .realtors:
      activeRealtors.count
    case .settings, .search:
      0
    }
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
  #endif

  /// Current path depth for lens state updates.
  /// Returns phonePath.count on iPhone, or current destination's path count on iPad/macOS.
  private var currentPathDepth: Int {
    #if os(iOS)
    if isPhone {
      return appState.router.phonePath.count
    } else {
      return appState.router.paths[appState.router.selectedDestination]?.count ?? 0
    }
    #else
    return appState.router.paths[appState.router.selectedDestination]?.count ?? 0
    #endif
  }

  private var bodyCore: some View {
    ZStack {
      navigationContent

      // Offline indicator - bottom left
      if appState.syncCoordinator.isOffline {
        OfflineIndicator()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
          .padding()
      }

      #if DEBUG
      if ProcessInfo.processInfo.environment["DISPATCH_PROBE"] == "1" {
        Button(action: {
          appState.dispatch(.openSearch(initialText: "probe"))
        }) {
          Text("Architectural Probe")
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .accessibilityIdentifier("DispatchProbe")
        .zIndex(999)
      }
      #endif
    }
    .animation(.easeInOut(duration: 0.3), value: appState.syncCoordinator.isOffline)
    .onAppear { onAppearActions() }
    .onChange(of: currentUserId) { _, _ in updateWorkItemActions() }
    .onChange(of: userCache) { _, _ in updateWorkItemActions() }
    .onChange(of: appState.router.selectedDestination) { _, _ in updateLensState() }
    .onChange(of: currentPathDepth) { _, _ in updateLensState() }
  }

  @ViewBuilder
  private var navigationContent: some View {
    #if os(macOS)
    // macOS always uses sidebar navigation
    sidebarNavigation
    #else
    // iOS: iPhone = MenuPageView, iPad = TabView with sidebarAdaptable
    // Using device idiom (NOT size class) to avoid iPad Slide Over/Split View issues
    if isPhone {
      menuNavigation
    } else {
      ipadTabViewNavigation
    }
    #endif
  }

  /// Things 3-style menu page navigation for iPhone with pull-down search.
  /// Uses phonePath (single stack) instead of per-tab paths.
  private var menuNavigation: some View {
    ZStack {
      NavigationStack(path: phonePathBinding) {
        PullToSearchHost {
          MenuPageView()
        }
        .appDestinations()
      }
      .id(appState.router.phoneStackID)
      .overlay {
        // Search overlay - Driven by AppState Intent
        if case .search(let initialText) = appState.overlayState {
          SearchOverlay(
            isPresented: Binding(
              get: { true },
              set: { if !$0 { appState.overlayState = .none } }
            ),
            searchText: $quickFindText,
            onSelectResult: { result in
              selectSearchResult(result)
              appState.overlayState = .none
            }
          )
          .onAppear {
            quickFindText = initialText ?? ""
          }
        }
      }

      // Persistent floating buttons
      // Helper to hide buttons when overlay is active (One Boss)
      if appState.overlayState == .none {
        GlobalFloatingButtons()
      }
    }
    .onAppear {
      // Keyboard observer relies on legacy AppOverlayState logic which we are deprecating.
      // Leaving attached to local 'overlayState' variable for now if it exists,
      // but we must clean up 'overlayState' variable usage.
      // For this step, we just comment it out as it was iOS specific fallback.
      // keyboardObserver.attach(to: overlayState)
    }
    // iOS Sheet Handling now driven by AppState
    // Note: We use the same sheet logic as macOS eventually, but for now we map it here
    .sheet(item: appState.sheetBinding) { state in
      switch state {
      case .quickEntry(let type):
        QuickEntrySheet(
          defaultItemType: type ?? .task,
          currentUserId: currentUserId,
          listings: activeListings,
          onSave: { syncManager.requestSync() }
        )

      case .addListing:
        AddListingSheet(
          currentUserId: currentUserId,
          onSave: { syncManager.requestSync() }
        )

      case .addRealtor:
        EditRealtorSheet()

      case .none:
        EmptyView()
      }
    }
  }

  @ViewBuilder
  private var quickFindOverlay: some View {
    #if os(macOS)
    if case .search(let initialText) = appState.overlayState {
      ZStack(alignment: .top) {
        // Dimmer Background (Click to dismiss)
        Color.black.opacity(0.1) // Transparent enough to see content, tangible enough to click
          .edgesIgnoringSafeArea(.all)
          .onTapGesture {
            appState.overlayState = .none
          }

        // The Popover Itself
        NavigationPopover(
          searchText: $quickFindText,
          isPresented: Binding(
            get: { true },
            set: { if !$0 { appState.overlayState = .none } }
          ),
          currentTab: selectedTab,
          onNavigate: { tab in
            appState.dispatch(.selectTab(tab))

            // Post filters logic
            // TODO: Refine this logic in next step
            appState.dispatch(tab == .listings ? .filterUnclaimed : .filterMine)
            appState.overlayState = .none
          },
          onSelectResult: { result in
            selectSearchResult(result)
            appState.overlayState = .none
          }
        )
        .padding(.top, 100) // Position it nicely near the top
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
          if let text = initialText {
            // Wait for popover animation + autofocus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
              quickFindText = text
            }
          }
        }
      }
      .zIndex(100) // Ensure it floats above everything
    }
    #endif
  }

  #if os(macOS)
  @ViewBuilder
  private func sheetContent(for state: AppState.SheetState) -> some View {
    switch state {
    case .quickEntry(let type):
      QuickEntrySheet(
        defaultItemType: type ?? .task,
        currentUserId: currentUserId,
        listings: activeListings,
        onSave: { syncManager.requestSync() }
      )

    case .addListing:
      AddListingSheet(
        currentUserId: currentUserId,
        onSave: { syncManager.requestSync() }
      )

    case .addRealtor:
      EditRealtorSheet()

    case .none:
      EmptyView()
    }
  }

  /// Binding wrapper to make SheetState work with `.sheet(item:)` which requires Optional
  private var sheetStateBinding: Binding<AppState.SheetState?> {
    Binding<AppState.SheetState?>(
      get: {
        appState.sheetState == .none ? nil : appState.sheetState
      },
      set: { newValue in
        appState.sheetState = newValue ?? .none
      }
    )
  }
  #endif

  /// Create binding for specific destination's path (iPad/macOS per-destination stacks).
  private func pathBinding(for destination: SidebarDestination) -> Binding<[AppRoute]> {
    Binding(
      get: { appState.router.paths[destination] ?? [] },
      set: { appState.dispatch(.setPath($0, for: destination)) }
    )
  }

  #if os(iOS) || os(visionOS)
  // MARK: - iPad Sidebar Helpers

  private func sidebarCount(for tab: AppTab) -> Int {
    switch tab {
    case .workspace: workspaceTasks.count + workspaceActivities.count
    case .properties: activeProperties.count
    case .listings: activeListings.count
    case .realtors: activeRealtors.count
    case .settings, .search: 0
    }
  }

  private var sidebarOverdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }
  #endif

  private func onAppearActions() {
    updateWorkItemActions()
    updateLensState()
  }

  #if os(macOS)
  /// Global key handler for Type Travel
  private func handleGlobalKeyDown(_ event: NSEvent) -> NSEvent? {
    // Ignore if any modifiers are pressed (Cmd, Ctrl, Opt), except Shift
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    if !flags.isEmpty && flags != .shift {
      return event
    }

    // Ignore if a text field is currently focused (handles both TextEditor and TextField)
    if
      let window = NSApp.keyWindow,
      let responder = window.firstResponder
    {
      // Check for active field editor (NSTextView)
      if let textView = responder as? NSTextView, textView.isEditable {
        return event
      }
      // Check for direct NSTextField focus (often covers SwiftUI TextFields)
      if responder is NSTextField {
        return event
      }
    }

    // Check for alphanumeric characters
    if
      let chars = event.charactersIgnoringModifiers,
      chars.count == 1,
      let char = chars.first,
      char.isLetter || char.isNumber
    {
      // Trigger Quick Find with this character
      appState.dispatch(.openSearch(initialText: String(char)))
      return nil
    }
    return event
  }
  #endif

  /// Handles navigation after selecting a search result
  private func selectSearchResult(_ result: SearchResult) {
    switch result {
    case .task(let task):
      // Convert to Destination
      appState.dispatch(.selectTab(.workspace))
      appState.dispatch(.navigate(.workItem(.task(task))))
    case .activity(let activity):
      appState.dispatch(.selectTab(.workspace))
      appState.dispatch(.navigate(.workItem(.activity(activity))))
    case .listing(let listing):
      appState.dispatch(.selectTab(.listings))
      appState.dispatch(.navigate(.listing(listing.id)))
    case .navigation(_, _, let tab, _):
      #if os(iOS)
      if isPhone {
        // iPhone: Clear stack first, then push destination
        // This ensures back button always returns to Menu page
        appState.dispatch(.phonePopToRoot)
        let route: AppRoute =
          switch tab {
          case .workspace: .workspace
          case .properties: .propertiesList
          case .listings: .listingsList
          case .realtors: .realtorsList
          case .settings: .settingsRoot
          case .search: .workspace
          }
        appState.dispatch(.phoneNavigateTo(route))
      } else {
        // iPad uses sidebar selection
        appState.dispatch(.selectTab(tab))
      }
      #else
      // macOS uses sidebar selection
      appState.dispatch(.selectTab(tab))
      #endif
    }
  }

  /// Updates the WorkItemActions environment object with current state and callbacks
  private func updateWorkItemActions() {
    workItemActions.currentUserId = currentUserId
    workItemActions.userLookup = { [userCache] id in userCache[id] }

    workItemActions.onComplete = { [syncManager] item in
      switch item {
      case .task(let task, _):
        task.status = task.status == .completed ? .open : .completed
        task.completedAt = task.status == .completed ? Date() : nil
        task.markPending()

      case .activity(let activity, _):
        activity.status = activity.status == .completed ? .open : .completed
        activity.completedAt = activity.status == .completed ? Date() : nil
        activity.markPending()
      }
      syncManager.requestSync()
    }

    workItemActions.onClaim = { [syncManager, currentUserId] item in
      switch item {
      case .task(let task, _):
        task.claimedBy = currentUserId
        task.claimedAt = Date()
        task.markPending()
        let event = ClaimEvent(
          parentType: .task,
          parentId: task.id,
          action: .claimed,
          userId: currentUserId
        )
        task.claimHistory.append(event)

      case .activity(let activity, _):
        activity.claimedBy = currentUserId
        activity.claimedAt = Date()
        activity.markPending()
        let event = ClaimEvent(
          parentType: .activity,
          parentId: activity.id,
          action: .claimed,
          userId: currentUserId
        )
        activity.claimHistory.append(event)
      }
      syncManager.requestSync()
    }

    workItemActions.onRelease = { [syncManager, currentUserId] item in
      switch item {
      case .task(let task, _):
        task.claimedBy = nil
        task.claimedAt = nil
        task.markPending()
        let event = ClaimEvent(
          parentType: .task,
          parentId: task.id,
          action: .released,
          userId: currentUserId
        )
        task.claimHistory.append(event)

      case .activity(let activity, _):
        activity.claimedBy = nil
        activity.claimedAt = nil
        activity.markPending()
        let event = ClaimEvent(
          parentType: .activity,
          parentId: activity.id,
          action: .released,
          userId: currentUserId
        )
        activity.claimHistory.append(event)
      }
      syncManager.requestSync()
    }

    workItemActions.onAddNote = { [syncManager, currentUserId] content, item in
      switch item {
      case .task(let task, _):
        let note = Note(
          content: content,
          createdBy: currentUserId,
          parentType: .task,
          parentId: task.id
        )
        task.notes.append(note)
        task.markPending()

      case .activity(let activity, _):
        let note = Note(
          content: content,
          createdBy: currentUserId,
          parentType: .activity,
          parentId: activity.id
        )
        activity.notes.append(note)
        activity.markPending()
      }
      syncManager.requestSync()
    }

    workItemActions.onDeleteNote = { [syncManager] note, _ in
      note.softDelete()
      syncManager.requestSync()
    }

    workItemActions.onToggleSubtask = { [syncManager] subtask in
      subtask.completed.toggle()
      syncManager.requestSync()
    }

    workItemActions.onDeleteSubtask = { [syncManager, modelContext] subtask, item in
      switch item {
      case .task(let task, _):
        task.subtasks.removeAll { $0.id == subtask.id }
        task.markPending()

      case .activity(let activity, _):
        activity.subtasks.removeAll { $0.id == subtask.id }
        activity.markPending()
      }
      modelContext.delete(subtask)
      syncManager.requestSync()
    }

    // Note: onAddSubtask requires showing a sheet, which is handled by the detail view
    // The WorkItemActions passes a callback that triggers local state in the resolved view
  }

  /// Pure function to derive the current "Screen" (Lens Context) from Router State.
  /// Eliminates the need for .onAppear hacks in views.
  private func updateLensState() {
    let destination = appState.router.selectedDestination
    let pathDepth = currentPathDepth

    // iPhone Root Logic: If phone and at root, we are at Menu
    #if os(iOS)
    if isPhone, pathDepth == 0 {
      if appState.lensState.currentScreen != .menu {
        appState.lensState.currentScreen = .menu
      }
      return
    }
    #endif

    let newScreen: LensState.CurrentScreen =
      switch destination {
      case .tab(let tab):
        switch tab {
        case .workspace:
          // Workspace always allows filtering (My Tasks vs All)
          .myWorkspace

        case .properties:
          // Properties list - no filtering needed
          .other

        case .listings:
          // List = No Filter, Detail = Filter (Audience/Kind)
          if pathDepth > 0 {
            .listingDetail
          } else {
            .listings
          }

        case .realtors:
          // Realtors currently has no global filtering in header
          .realtors

        case .settings:
          // Settings has no filtering
          .other

        case .search:
          .other
        }

      case .stage:
        // Stage destinations are listing-context screens
        if pathDepth > 0 {
          .listingDetail
        } else {
          .listings
        }
      }

    if appState.lensState.currentScreen != newScreen {
      appState.lensState.currentScreen = newScreen
    }
  }

}

#Preview {
  ContentView()
    .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
    .environmentObject(SyncManager.shared)
    .environmentObject(AppState(mode: .preview))
}
