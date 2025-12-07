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
    var body: some View {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
        .environmentObject(SyncManager.shared)
}
