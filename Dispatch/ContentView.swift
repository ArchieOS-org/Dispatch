//
//  ContentView.swift
//  Dispatch
//
//  Root TabView navigation for the Dispatch app
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI
import SwiftData

/// Root view providing TabView navigation between:
/// - Tasks: TaskListView with segmented filter and date sections
/// - Activities: ActivityListView with same structure
/// - Listings: ListingListView grouped by owner with search
struct ContentView: View {
    @EnvironmentObject private var syncManager: SyncManager

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                TaskListView()
                    .tabItem {
                        Label("Tasks", systemImage: DS.Icons.Entity.task)
                    }

                ActivityListView()
                    .tabItem {
                        Label("Activities", systemImage: DS.Icons.Entity.activity)
                    }

                ListingListView()
                    .tabItem {
                        Label("Listings", systemImage: DS.Icons.Entity.listing)
                    }
            }

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
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
