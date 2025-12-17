//
//  ContentView.swift
//  Dispatch
//
//  Root TabView navigation for the Dispatch app
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
/// - iPhone/iPad Portrait: TabView navigation
/// - iPad Landscape/macOS: NavigationSplitView with sidebar (Things3-like)
struct ContentView: View {
    @EnvironmentObject private var syncManager: SyncManager

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    enum Tab: Hashable {
        case tasks, activities, listings
    }

    @State private var selectedTab: Tab = .tasks

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
    }

    @ViewBuilder
    private var navigationContent: some View {
        #if os(macOS)
        // macOS always uses sidebar navigation
        sidebarNavigation
        #else
        // iOS: Portrait = TabView, Landscape (regular width) = Sidebar
        if horizontalSizeClass == .regular {
            sidebarNavigation
        } else {
            tabNavigation
        }
        #endif
    }

    private var tabNavigation: some View {
        TabView(selection: $selectedTab) {
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: DS.Icons.Entity.task)
                }
                .tag(Tab.tasks)

            ActivityListView()
                .tabItem {
                    Label("Activities", systemImage: DS.Icons.Entity.activity)
                }
                .tag(Tab.activities)

            ListingListView()
                .tabItem {
                    Label("Listings", systemImage: DS.Icons.Entity.listing)
                }
                .tag(Tab.listings)
        }
    }

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
            switch selectedTab {
            case .tasks:
                TaskListView()
            case .activities:
                ActivityListView()
            case .listings:
                ListingListView()
            }
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
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
