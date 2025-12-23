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

    // MARK: - Search State (iPhone only)

    @StateObject private var searchManager = SearchPresentationManager()
    @State private var searchNavigationPath = NavigationPath()

    // MARK: - Global Filter & Overlay State (iPhone only)

    @StateObject private var lensState = LensState()
    @StateObject private var quickEntryState = QuickEntryState()
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
    }

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
                    .environmentObject(searchManager)
                    .environmentObject(overlayState)
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
        switch result {
        case .task(let task):
            searchNavigationPath.append(WorkItemRef.task(task))
        case .activity(let activity):
            searchNavigationPath.append(WorkItemRef.activity(activity))
        case .listing(let listing):
            searchNavigationPath.append(listing)
        }
    }

    // MARK: - iPad/macOS Sidebar Navigation

    private var sidebarNavigation: some View {
        NavigationSplitView {
            #if os(macOS)
            List(selection: $selectedTab) {
                Label("Tasks", systemImage: DS.Icons.Entity.task)
                    .tag(Tab.tasks)
                Label("Activities", systemImage: DS.Icons.Entity.activity)
                    .tag(Tab.activities)
                Label("Listings", systemImage: DS.Icons.Entity.listing)
                    .tag(Tab.listings)
            }
            .navigationTitle("Dispatch")
            #else
            List {
                sidebarButton(for: .tasks, label: "Tasks", icon: DS.Icons.Entity.task)
                sidebarButton(for: .activities, label: "Activities", icon: DS.Icons.Entity.activity)
                sidebarButton(for: .listings, label: "Listings", icon: DS.Icons.Entity.listing)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dispatch")
            #endif
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

    #if os(iOS)
    @ViewBuilder
    private func sidebarButton(for tab: Tab, label: String, icon: String) -> some View {
        Button {
            selectedTab = tab
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
