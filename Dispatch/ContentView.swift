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
    @Environment(\.modelContext) private var modelContext

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Query private var users: [User]
    @Query private var allListings: [Listing]

    enum Tab: Hashable {
        case tasks, activities, listings
    }

    @State private var selectedTab: Tab = .tasks

    /// Centralized WorkItemActions environment object for shared navigation
    @StateObject private var workItemActions = WorkItemActions()

    // MARK: - macOS Bottom Toolbar State

    #if os(macOS)
    @State private var showMacOSQuickEntry = false
    @State private var showMacOSAddListing = false
    
    // Global Quick Find (Popover) State
    @State private var showQuickFind = false
    @State private var quickFindText = ""
    #endif

    // MARK: - Search State (iPhone only)

    @StateObject private var searchManager = SearchPresentationManager()
    @State private var searchNavigationPath = NavigationPath()
    @State private var stackID = UUID() // Used to force-refresh navigation stack on root pop
    
    // ... (rest of environment objects)

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            navigationContent

            if case .error = syncManager.syncStatus {
                SyncStatusBanner(
                    message: syncManager.lastSyncErrorMessage ?? "Sync failed",
                    onRetry: { syncManager.requestSync() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: syncManager.syncStatus)
        .onAppear {
            updateWorkItemActions()
        }
        .onChange(of: currentUserId) { _, _ in
            updateWorkItemActions()
        }
        .onChange(of: userCache) { _, _ in
            updateWorkItemActions()
        }
        // Inject environment objects at root so both navigation paths inherit them
        .environmentObject(workItemActions)
        .environmentObject(searchManager)
        .environmentObject(lensState)
        .environmentObject(quickEntryState)
        .environmentObject(overlayState)
        #if os(macOS)
        .background(KeyMonitorView { event in
            handleGlobalKeyDown(event)
        })
        .sheet(isPresented: $showQuickFind) {
            NavigationPopover(
                searchText: $quickFindText,
                isPresented: $showQuickFind,
                currentTab: selectedTab, // Now global!
                onNavigate: { tab in
                    // Navigation Logic (Unified)
                    handleTabSelection(tab)

                    // Post filters if needed (legacy support for containers listening)
                    switch tab {
                    case .tasks: NotificationCenter.default.post(name: .filterMine, object: nil)
                    case .activities: NotificationCenter.default.post(name: .filterOthers, object: nil)
                    case .listings: NotificationCenter.default.post(name: .filterUnclaimed, object: nil)
                    }
                    showQuickFind = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { notification in
            if let initialText = notification.userInfo?["initialText"] as? String {
                // Wait for popover animation + autofocus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    quickFindText = initialText
                }
            }
            showQuickFind = true
        }
        #endif
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
            NotificationCenter.default.post(
                name: .openSearch,
                object: nil,
                userInfo: ["initialText": String(char)]
            )
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
            NavigationStack(path: $searchNavigationPath) {
                MenuPageView()
                    .dispatchDestinations()
            }
            .overlay {
                // Search overlay
                if searchManager.isSearchPresented {
                    SearchOverlay(
                        isPresented: $searchManager.isSearchPresented,
                        searchText: $searchManager.searchText,
                        onSelectResult: { result in
                            selectSearchResult(result)
                        }
                    )
                }
            }
            .syncNowToolbar()

            // Persistent floating buttons
            GlobalFloatingButtons()
        }
        .onAppear {
            // Attach keyboard observer (iPhone-only fallback)
            keyboardObserver.attach(to: overlayState)
        }
        .sheet(isPresented: $quickEntryState.isPresenting) {
            QuickEntrySheet(
                defaultItemType: quickEntryState.defaultItemType,
                currentUserId: currentUserId,
                listings: activeListings,
                onSave: { syncManager.requestSync() }
            )
        }
    }

    // MARK: - Search Navigation

    /// Handles navigation after selecting a search result
    private func selectSearchResult(_ result: SearchResult) {
        // Helper to switch tab and push destination
        func navigate(to tab: Tab, destination: any Hashable) {
            if selectedTab != tab {
                selectedTab = tab
                searchNavigationPath = NavigationPath() // Clear previous tab's stack
            }
            // If already on tab, we don't clear stack (unlike sidebar click), 
            // BUT we probably want to show this result on top? 
            // Or should searching ALWAYS clear stack?
            // "Type Travel" usually implies jumping to the thing. 
            // Let's clear stack to be safe and avoid confusing history.
            searchNavigationPath = NavigationPath() 
            searchNavigationPath.append(destination)
        }

        switch result {
        case .task(let task):
            navigate(to: .tasks, destination: WorkItemRef.task(task))
        case .activity(let activity):
            navigate(to: .activities, destination: WorkItemRef.activity(activity))
        case .listing(let listing):
            navigate(to: .listings, destination: listing)
        case .navigation(_, _, let tab, _):
            handleTabSelection(tab) // Use the standard handler
            #if !os(macOS)
             // iPhone specific logic if needed
            #endif
        }
    }

    // MARK: - iPad/macOS Sidebar Navigation

    // MARK: - Navigation Logic
    
    /// centralized handler for sidebar/tab interactions
    /// - Implements "Pop to Root" behavior when clicking the active tab
    /// - Clears navigation stack when switching tabs to ensure a clean slate
    private func handleTabSelection(_ tab: Tab) {
        if selectedTab == tab {
            // "Pop to Root": Clear navigation stack if already on this tab
            searchNavigationPath = NavigationPath()
            // Force re-identity of the stack to ensure UI update
            stackID = UUID()
        } else {
            // Switch tabs and clear any existing navigation state
            selectedTab = tab
            searchNavigationPath = NavigationPath()
            // Fresh stack identity for new tab
            stackID = UUID()
        }
    }
    
    // MARK: - iPad/macOS Sidebar Navigation
    
    #if os(macOS)
    /// Toolbar context based on current tab selection
    private var toolbarContext: ToolbarContext {
        switch selectedTab {
        case .tasks:
            return .taskList
        case .activities:
            return .activityList
        case .listings:
            return .listingList
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
                        title: "Tasks",
                        icon: DS.Icons.Entity.task,
                        isSelected: selectedTab == .tasks,
                        action: { handleTabSelection(.tasks) }
                    )
                    
                    SidebarRow(
                        title: "Activities",
                        icon: DS.Icons.Entity.activity,
                        isSelected: selectedTab == .activities,
                        action: { handleTabSelection(.activities) }
                    )
                    
                    SidebarRow(
                        title: "Listings",
                        icon: DS.Icons.Entity.listing,
                        isSelected: selectedTab == .listings,
                        action: { handleTabSelection(.listings) }
                    )
                }
            }
            .listStyle(.sidebar)
        } content: {
            NavigationStack(path: $searchNavigationPath) {
                Group {
                    switch selectedTab {
                    case .tasks:
                        TaskListView()
                    case .activities:
                        ActivityListView()
                    case .listings:
                        ListingListView()
                    }
                }
                .dispatchDestinations()
            }
            // toolbar(.hidden) removed to restore traffic lights
            .id(stackID) // Force rebuild when ID changes (pop to root)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomToolbar(
                    context: toolbarContext,
                    onNew: {
                        if selectedTab == .listings {
                            showMacOSAddListing = true
                        } else {
                            showMacOSQuickEntry = true
                        }
                    },
                    onSearch: {
                        NotificationCenter.default.post(name: .openSearch, object: nil)
                    }
                )
            }
        }
        .sheet(isPresented: $showMacOSQuickEntry) {
            QuickEntrySheet(
                defaultItemType: selectedTab == .activities ? .activity : .task,
                currentUserId: currentUserId,
                listings: activeListings,
                onSave: { syncManager.requestSync() }
            )
        }
        .sheet(isPresented: $showMacOSAddListing) {
            AddListingSheet(
                currentUserId: currentUserId,
                onSave: { syncManager.requestSync() }
            )
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .newItem)) { _ in
            if selectedTab == .listings {
                showMacOSAddListing = true
            } else {
                showMacOSQuickEntry = true
            }
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .navigateSearchResult)) { notification in
            if let result = notification.userInfo?["result"] as? SearchResult {
                selectSearchResult(result)
            }
        }
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
                sidebarButton(for: .tasks, label: "Tasks", icon: DS.Icons.Entity.task)
                sidebarButton(for: .activities, label: "Activities", icon: DS.Icons.Entity.activity)
                sidebarButton(for: .listings, label: "Listings", icon: DS.Icons.Entity.listing)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dispatch")
        } detail: {
            Group {
                switch selectedTab {
                case .tasks:
                    TaskListView()
                case .activities:
                    ActivityListView()
                case .listings:
                    ListingListView()
                }
            }
            .syncNowToolbar()
        }
        .navigationSplitViewStyle(.balanced)
    }
    #endif
    
    #if os(iOS) || os(visionOS)
    @ViewBuilder
    private func sidebarButton(for tab: Tab, label: String, icon: String) -> some View {
        Button {
            handleTabSelection(tab)
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

        workItemActions.onDeleteNote = { [syncManager, modelContext] note, item in
            switch item {
            case .task(let task, _):
                task.notes.removeAll { $0.id == note.id }
                task.markPending()
            case .activity(let activity, _):
                activity.notes.removeAll { $0.id == note.id }
                activity.markPending()
            }
            modelContext.delete(note)
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
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
