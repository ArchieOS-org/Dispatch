//
//  MacContentView.swift
//  Dispatch
//
//  macOS-specific navigation view extracted from ContentView.
//  Uses native NavigationSplitView for true Xcode/Finder sidebar appearance.
//

#if os(macOS)
import SwiftUI

/// macOS navigation container with native NavigationSplitView sidebar.
/// Extracted from ContentView to reduce complexity and enable platform-specific optimizations.
struct MacContentView: View {

  // MARK: Internal

  /// Stage counts for sidebar cards
  let stageCounts: [ListingStage: Int]

  /// Workspace tasks for sidebar counts
  let workspaceTasks: [TaskItem]

  /// Workspace activities for sidebar counts
  let workspaceActivities: [Activity]

  /// Active listings for sidebar counts
  let activeListings: [Listing]

  /// Active properties for sidebar counts
  let activeProperties: [Property]

  /// Active realtors for sidebar counts
  let activeRealtors: [User]

  /// All users for sheets
  let users: [User]

  /// Current user ID for sheets
  let currentUserId: UUID

  /// Function to create path binding for a destination
  let pathBindingProvider: (SidebarDestination) -> Binding<[AppRoute]>

  /// Callback when search result is selected
  let onSelectSearchResult: (SearchResult) -> Void

  /// Callback to request sync after save
  let onRequestSync: () -> Void

  var body: some View {
    ZStack {
      sidebarNavigation
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      // Bottom toolbar at root level - spans full width including under sidebar
      // Note: macOS does not have native `.bottomBar` toolbar placement,
      // so we use `.safeAreaInset` which is the correct pattern for bottom bars on macOS.
      BottomToolbar(
        context: bottomToolbarContext,
        audience: $appState.lensState.audience,
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
          windowUIState.openSearch(initialText: nil)
        },
        onDuplicateWindow: {
          openWindow(id: "main")
        },
        duplicateWindowDisabled: !supportsMultipleWindows
      )
    }
    .overlay(alignment: .top) {
      quickFindOverlay
    }
    .sheet(item: sheetStateBinding) { state in
      sheetContent(for: state)
    }
    // Listen for menu bar Cmd+F notification (per-window handling)
    // Only respond if THIS window is the key (focused) window
    .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in
      if controlActiveState == .key {
        windowUIState.openSearch(initialText: nil)
      }
    }
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager

  /// Per-window UI state (sidebar, overlays) - each window gets its own instance
  @Environment(WindowUIState.self) private var windowUIState

  /// Window management for duplicate window action
  @Environment(\.openWindow) private var openWindow
  @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

  /// Tracks whether this window is the key (focused) window
  @Environment(\.controlActiveState) private var controlActiveState

  /// Focus state for the main content area - enables type-to-search
  @FocusState private var contentAreaFocused: Bool

  /// Global Quick Find (Popover) State
  @State private var quickFindText = ""

  /// Controls sidebar column visibility for native NavigationSplitView
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  /// Computed binding for List(selection:) that bridges non-optional AppState to optional List API.
  /// - Get: Returns nil for stage destinations (shown deselected), otherwise the destination
  /// - Set: Dispatches to AppState, ignoring nil (which shouldn't occur from List selection)
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
        // Task schedules the dispatch for the next run loop iteration.
        Task { @MainActor in
          appState.dispatch(.userSelectedDestination(dest))
        }
      }
    )
  }

  /// Bottom toolbar context derived from selected destination (for Things 3-style toolbar)
  private var bottomToolbarContext: ToolbarContext {
    switch appState.router.selectedDestination {
    case .tab(let tab):
      switch tab {
      case .workspace:
        .taskList
      case .properties:
        .listingList
      case .listings:
        .listingList
      case .realtors:
        .realtorList
      case .settings, .search:
        .taskList
      }

    case .stage:
      .listingList
    }
  }

  private var sidebarOverdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }

  /// macOS: Native NavigationSplitView for true Xcode/Finder sidebar appearance.
  /// Uses UnifiedSidebarContent for consistent sidebar UI across platforms.
  /// Settings uses SettingsLink via inline row.
  private var sidebarNavigation: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      // Unified sidebar content component (shared with iPad)
      UnifiedSidebarContent(
        stageCounts: stageCounts,
        tabCounts: macTabCounts,
        overdueCount: sidebarOverdueCount,
        selection: sidebarSelectionBinding,
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
      .toolbar {
        // Ensure the NSToolbar exists at all times.
        // This prevents the window corner radius from flickering (Large vs Small)
        // when navigating between views.
        ToolbarItem(placement: .primaryAction) {
          Color.clear.frame(width: 0, height: 0)
        }
      }
      // Type Travel: alphanumeric keys open search with typed character
      // Uses SwiftUI's native .onKeyPress() which is inherently window-scoped
      .focusable()
      .focused($contentAreaFocused)
      .focusEffectDisabled() // Disable blue focus ring while keeping keyboard focus
      .onKeyPress(characters: .alphanumerics, phases: .down) { keyPress in
        // Skip if modifiers are pressed (except Shift for uppercase)
        guard keyPress.modifiers.subtracting(.shift).isEmpty else {
          return .ignored
        }

        // Skip if overlay is already showing
        guard case .none = windowUIState.overlayState else {
          return .ignored
        }

        // Open search with the typed character
        windowUIState.openSearch(initialText: String(keyPress.characters))
        return .handled
      }
      // Escape key: pop navigation stack (only when not in overlay)
      // Menu bar handles this via DispatchCommands, but this provides direct handling
      // when focus is in the content area
      .onKeyPress(.escape) {
        // If overlay is showing, close it instead of popping navigation
        if case .search = windowUIState.overlayState {
          windowUIState.closeOverlay()
          return .handled
        }

        // Pop navigation if we have a non-empty stack
        let currentPath = appState.router.paths[appState.router.selectedDestination] ?? []
        if !currentPath.isEmpty {
          appState.dispatch(.popNavigation)
          return .handled
        }

        return .ignored
      }
      .onAppear {
        // Auto-focus content area when view appears
        contentAreaFocused = true
      }
      .onChange(of: windowUIState.overlayState) { oldValue, newValue in
        // Re-focus content area when overlay closes
        if case .none = newValue, case .search = oldValue {
          // Use Task for delay - automatically cancelled if view disappears
          Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            contentAreaFocused = true
          }
        }
      }
    }
    .navigationSplitViewStyle(.balanced)
    .modifier(ToolbarBackgroundModifier())
    // Handle sidebar toggle via notification (Cmd+/)
    .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
      withAnimation {
        columnVisibility = columnVisibility == .all ? .detailOnly : .all
      }
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

  // MARK: - Quick Find Overlay

  @ViewBuilder
  private var quickFindOverlay: some View {
    if case .search(let initialText) = windowUIState.overlayState {
      ZStack(alignment: .top) {
        // Dimmer Background (Click to dismiss)
        Color.black.opacity(0.1) // Transparent enough to see content, tangible enough to click
          .edgesIgnoringSafeArea(.all)
          .onTapGesture {
            windowUIState.closeOverlay()
          }

        // The Popover Itself
        NavigationPopover(
          searchText: $quickFindText,
          isPresented: Binding(
            get: { true },
            set: { if !$0 { windowUIState.closeOverlay() } }
          ),
          currentTab: appState.router.selectedTab,
          onNavigate: { tab in
            appState.dispatch(.selectTab(tab))
            windowUIState.closeOverlay()
          },
          onSelectResult: { result in
            onSelectSearchResult(result)
            windowUIState.closeOverlay()
          }
        )
        .padding(.top, 100) // Position it nicely near the top
        .transition(.move(edge: .top).combined(with: .opacity))
        .task(id: initialText) {
          if let text = initialText {
            // Wait for popover animation + autofocus
            try? await Task.sleep(for: .milliseconds(150))
            quickFindText = text
          }
        }
      }
      .zIndex(100) // Ensure it floats above everything
    }
  }

  /// Binding wrapper to make SheetState work with `.sheet(item:)` which requires Optional
  private var sheetStateBinding: Binding<AppState.SheetState?> {
    Binding<AppState.SheetState?>(
      get: {
        appState.sheetState == .none ? nil : appState.sheetState
      },
      set: { newValue in
        // Defer state change to avoid "Publishing changes from within view updates" warning.
        // Task schedules the mutation for the next run loop iteration.
        Task { @MainActor in
          appState.sheetState = newValue ?? .none
        }
      }
    )
  }

  // MARK: - Sidebar Helpers

  private func sidebarCount(for tab: AppTab) -> Int {
    switch tab {
    case .workspace: workspaceTasks.count + workspaceActivities.count
    case .properties: activeProperties.count
    case .listings: activeListings.count
    case .realtors: activeRealtors.count
    case .settings, .search: 0
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

  // MARK: - Sheet Content

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

// MARK: - Toolbar Background Modifier

/// Hides the window toolbar background on macOS 26+ to let content inform toolbar appearance.
/// Per HIG: "Reduce the use of toolbar backgrounds and tinted controls. Instead, use the
/// content layer to inform the color and appearance of the toolbar."
private struct ToolbarBackgroundModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 26, *) {
      content
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    } else {
      content
    }
  }
}
#endif
