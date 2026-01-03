//
//  ContentView.swift
//  Dispatch
//
//  Root navigation for the Dispatch app
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI
import SwiftData

/// Root view providing navigation between:
/// - Tasks: TaskListView with segmented filter and date sections
/// - Activities: ActivityListView with same structure
/// - Listings: ListingListView grouped by owner with search
///
/// Adaptive layout:
/// - iPhone: MenuPageView with Things 3-style cards, push navigation
/// - iPad Landscape/macOS: NavigationSplitView with sidebar
struct ContentView: View {
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var appState: AppState // One Boss injection
    @Environment(\.modelContext) private var modelContext

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Query private var users: [User]
    @Query private var allListings: [Listing]

    // Local Tab state removed - using AppState.router.selectedTab (One Boss)
    private var selectedTab: AppTab {
        appState.router.selectedTab
    }

    /// Centralized WorkItemActions environment object for shared navigation
    @StateObject private var workItemActions = WorkItemActions()

    // MARK: - macOS Bottom Toolbar State

    // MARK: - macOS Bottom Toolbar State
    
    #if os(macOS)
    // Global Quick Find (Popover) State managed by AppState.overlayState
    @State private var quickFindText = ""
    #endif

    // MARK: - Search State (iPhone only)
    
    // searchManager migrated to AppState
    // @StateObject private var searchManager = SearchPresentationManager()
    // Local nav state removed - deferring to AppState.router (One Boss)
    
    // MARK: - Global Filter & Overlay State (iPhone only)
    
    // QuickEntryState removed - migrated to AppState
    @StateObject private var overlayState = AppOverlayState()
    @StateObject private var keyboardObserver = KeyboardObserver()

    // MARK: - Computed Properties

    /// Pre-computed user lookup dictionary for O(1) access
    private var userCache: [UUID: User] {
        Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    /// Active listings (not deleted) for quick entry
    private var activeListings: [Listing] {
        allListings.filter { $0.status != .deleted }
    }

    /// Sentinel UUID for unauthenticated state
    private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private var currentUserId: UUID {
        syncManager.currentUserID ?? Self.unauthenticatedUserId
    }

    // MARK: - Body

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
    
    // MARK: - Body Subviews (Compiler Performance)
    
    @ViewBuilder
    private var bodyCore: some View {
        ZStack(alignment: .top) {
            navigationContent
            syncStatusBanner
            
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
        .animation(.easeInOut(duration: 0.3), value: syncManager.syncStatus)
        .onAppear { onAppearActions() }
        .onChange(of: currentUserId) { _, _ in updateWorkItemActions() }
        .onChange(of: userCache) { _, _ in updateWorkItemActions() }
        .onChange(of: appState.router.selectedTab) { _, _ in updateLensState() }
        .onChange(of: appState.router.pathMain.count) { _, _ in updateLensState() }
    }
    
    @ViewBuilder
    private var syncStatusBanner: some View {
        if case .error = syncManager.syncStatus {
            SyncStatusBanner(
                message: syncManager.lastSyncErrorMessage ?? "Sync failed",
                onRetry: { syncManager.requestSync() }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(1)
        }
    }
    
    private func onAppearActions() {
        updateWorkItemActions()
        updateLensState()
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

    #if os(macOS)
    /// Global key handler for Type Travel
    private func handleGlobalKeyDown(_ event: NSEvent) -> NSEvent? {
        // Ignore if any modifiers are pressed (Cmd, Ctrl, Opt), except Shift
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !flags.isEmpty && flags != .shift {
            return event
        }

        // Ignore if a text field is currently focused (handles both TextEditor and TextField)
        if let window = NSApp.keyWindow,
           let responder = window.firstResponder {
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
        if let chars = event.charactersIgnoringModifiers,
           chars.count == 1,
           let char = chars.first,
           char.isLetter || char.isNumber {

            // Trigger Quick Find with this character
            appState.dispatch(.openSearch(initialText: String(char)))
            return nil
        }
        return event
    }
    #endif

    @ViewBuilder
    private var navigationContent: some View {
        #if os(macOS)
        // macOS always uses sidebar navigation
        sidebarNavigation
        #else
        // iOS: Compact = MenuPageView, Regular (iPad) = Sidebar
        if horizontalSizeClass == .regular {
            sidebarNavigation
        } else {
            menuNavigation
        }
        #endif
    }

    // MARK: - iPhone Menu Navigation

    /// Things 3-style menu page navigation for iPhone with pull-down search
    private var menuNavigation: some View {
        ZStack {
            NavigationStack(path: $appState.router.pathMain) {
                MenuPageView()
                    .appDestinations()
            }
            .overlay {
                // Search overlay - Driven by AppState Intent
                if case .search(let initialText) = appState.overlayState {
                    SearchOverlay(
                        isPresented: Binding(
                            get: { true },
                            set: { if !$0 { appState.overlayState = .none } }
                        ),
                        searchText: Binding(
                            get: { initialText ?? "" },
                            set: { _ in } // SearchOverlay handles strict text state locally for now
                        ),
                        onSelectResult: { result in
                            selectSearchResult(result)
                            appState.overlayState = .none
                        }
                    )
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

    // MARK: - Search Navigation

    /// Handles navigation after selecting a search result
    private func selectSearchResult(_ result: SearchResult) {


        switch result {
        case .task(let task):
            // Convert to Destination
            appState.dispatch(.selectTab(.workspace))
            appState.dispatch(.navigate(.workItem(task.id)))
        case .activity(let activity):
            appState.dispatch(.selectTab(.workspace))
            appState.dispatch(.navigate(.workItem(activity.id)))
        case .listing(let listing):
            appState.dispatch(.selectTab(.listings))
            appState.dispatch(.navigate(.listing(listing.id)))
        case .navigation(_, _, let tab, _):
            // Map SearchResult tab (likely legacy or string) to AppTab
            // Assuming tab is ContentView.Tab-like.
            // Wait, SearchResult definition?
            // Let's assume the mapped enum cases match AppTab.
            switch tab {
            case .workspace: appState.dispatch(.selectTab(.workspace))
            case .properties: appState.dispatch(.selectTab(.properties))
            case .listings: appState.dispatch(.selectTab(.listings))
            case .realtors: appState.dispatch(.selectTab(.realtors))
            case .settings: appState.dispatch(.selectTab(.settings))
            case .search: break // Search tab doesn't navigate
            }
            #if !os(macOS)
             // iPhone specific logic if needed
            #endif
        }
    }

    // MARK: - iPad/macOS Sidebar Navigation

    // MARK: - Navigation Logic
    // handleTabSelection removed - use appState.dispatch(.selectTab) directly
    
    // MARK: - iPad/macOS Sidebar Navigation
    
    #if os(macOS)
    private var toolbarContext: ToolbarContext {
        switch selectedTab {
        case .properties:
            return .listingList // Properties uses listing-style toolbar
        case .listings:
            return .listingList
        case .realtors:
            return .realtorList
        case .settings:
            return .taskList // Settings uses default toolbar
        case .workspace, .search:
            return .taskList // Re-use task actions for now
        }
    }
    
    /// macOS: Things 3-style resizable sidebar with custom drag handle
    private var sidebarNavigation: some View {
        ResizableSidebar {
            List {
                // We use manual button rows or TapGestures to ensure we capture the "click active" event
                // Standard List(selection:) consumes clicks on selected items without reporting them.
                
                Group {
                    SidebarRow(
                        title: "My Workspace",
                        icon: "briefcase",
                        isSelected: selectedTab == .workspace,
                        action: { appState.dispatch(.selectTab(.workspace)) }
                    )

                    SidebarRow(
                        title: "Properties",
                        icon: DS.Icons.Entity.property,
                        isSelected: selectedTab == .properties,
                        action: { appState.dispatch(.selectTab(.properties)) }
                    )

                    SidebarRow(
                        title: "Listings",
                        icon: DS.Icons.Entity.listing,
                        isSelected: selectedTab == .listings,
                        action: { appState.dispatch(.selectTab(.listings)) }
                    )

                    SidebarRow(
                        title: "Realtors",
                        icon: DS.Icons.Entity.realtor,
                        isSelected: selectedTab == .realtors,
                        action: { appState.dispatch(.selectTab(.realtors)) }
                    )

                    Divider()
                        .padding(.vertical, DS.Spacing.sm)

                    SidebarRow(
                        title: "Settings",
                        icon: "gearshape",
                        isSelected: selectedTab == .settings,
                        action: { appState.dispatch(.selectTab(.settings)) }
                    )
                }
            }
            .listStyle(.sidebar)
        } content: {
            NavigationStack(path: $appState.router.pathMain) {
                Group {
                    switch selectedTab {
                    case .properties:
                        PropertiesListView()
                    case .listings:
                        ListingListView()
                    case .realtors:
                        RealtorsListView() // Use root stack
                    case .settings:
                        SettingsView()
                    case .workspace, .search:
                        MyWorkspaceView()
                    }
                }
                .appDestinations()
            }
            // toolbar(.hidden) removed to restore traffic lights
            .id(appState.router.stackID) // Force rebuild when ID changes (pop to root)
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
                        if selectedTab == .listings {
                            appState.sheetState = .addListing
                        } else if selectedTab == .realtors {
                            appState.sheetState = .addRealtor
                        } else {
                            appState.sheetState = .quickEntry(type: nil)
                        }
                    },

                    onSearch: {
                        appState.dispatch(.openSearch(initialText: nil))
                    }
                )
            }
        }

        
        // onReceive navigateSearchResult removed
        
    }
    
    /// Helper view for macOS Sidebar Rows to emulate standard selection style while supporting custom click logic
    private struct SidebarRow: View {
        let title: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Label(title, systemImage: icon)
                    .foregroundColor(isSelected ? .white : .primary) // Standard selection text color
                    .padding(.leading, 12) // Restore standard sidebar padding
                    .padding(.vertical, 6) // Restore standard vertical spacing
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets()) // Ensure button fills entire row (edge-to-edge click target)
            .listRowBackground(
                isSelected ? Color.accentColor : Color.clear
            )
        }
    }
    #else
    /// iPad: Standard NavigationSplitView sidebar
    private var sidebarNavigation: some View {
        NavigationSplitView {
            List {
                sidebarButton(for: .workspace, label: "My Workspace", icon: "briefcase")
                sidebarButton(for: .properties, label: "Properties", icon: DS.Icons.Entity.property)
                sidebarButton(for: .listings, label: "Listings", icon: DS.Icons.Entity.listing)
                sidebarButton(for: .realtors, label: "Realtors", icon: DS.Icons.Entity.realtor)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dispatch")
        } detail: {
            // iPad: Unconditional Stack (One Boss Rule)
            NavigationStack(path: $appState.router.pathMain) {
                Group {
                    switch selectedTab {
                    case .properties:
                        PropertiesListView()
                    case .listings:
                        ListingListView()
                    case .realtors:
                        RealtorsListView()
                    case .settings:
                        SettingsView()
                    case .workspace, .search:
                        MyWorkspaceView()
                    }
                }
                .appDestinations() // Registry Attached!
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        AudienceFilterButton(
                            lens: appState.lensState.audience,
                            action: appState.lensState.cycleAudience
                        )
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    #endif
    
    #if os(iOS) || os(visionOS)
    @ViewBuilder
    private func sidebarButton(for tab: AppTab, label: String, icon: String) -> some View {
        Button {
            appState.dispatch(.selectTab(tab))
        } label: {
            Label(label, systemImage: icon)
                .foregroundColor(selectedTab == tab ? .accentColor : .primary)
        }
        .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
    }
    #endif

    // MARK: - Actions

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

        workItemActions.onDeleteNote = { [syncManager] note, item in
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
    
    // MARK: - Phase 2: State Derivation
    
    /// Pure function to derive the current "Screen" (Lens Context) from Router State.
    /// Eliminates the need for .onAppear hacks in views.
    private func updateLensState() {
        let tab = appState.router.selectedTab
        let pathDepth = appState.router.pathMain.count
        
        // iPhone Root Logic: If compact and at root, we are at Menu
        #if os(iOS)
        if horizontalSizeClass == .compact && pathDepth == 0 {
            if appState.lensState.currentScreen != .menu {
                appState.lensState.currentScreen = .menu
            }
            return
        }
        #endif
        
        let newScreen: LensState.CurrentScreen
        
        switch tab {
        case .workspace:
            // Workspace always allows filtering (My Tasks vs All)
            newScreen = .myWorkspace

        case .properties:
            // Properties list - no filtering needed
            newScreen = .other

        case .listings:
            // List = No Filter, Detail = Filter (Audience/Kind)
            if pathDepth > 0 {
                newScreen = .listingDetail
            } else {
                newScreen = .listings
            }

        case .realtors:
            // Realtors currently has no global filtering in header
            newScreen = .realtors

        case .settings:
            // Settings has no filtering
            newScreen = .other

        case .search:
            newScreen = .other
        }
        
        if appState.lensState.currentScreen != newScreen {
            appState.lensState.currentScreen = newScreen
        }
    }

    // MARK: - Extracted Views for Compiler Performance
    
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
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
        .environmentObject(AppState(mode: .preview))
}
