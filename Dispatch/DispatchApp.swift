//
//  DispatchApp.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftUI
import SwiftData

@main
struct DispatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    @State private var showTestHarness = false
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            TaskItem.self,
            Activity.self,
            Listing.self,
            Note.self,
            Subtask.self,
            StatusChange.self,
            ClaimEvent.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Stub test user for MVP (replace with real auth later)
    // This UUID should match a user in your Supabase users table
    private let testUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init() {
        SyncManager.shared.configure(with: sharedModelContainer, testUserID: testUserID)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SyncManager.shared)
                #if DEBUG
                .sheet(isPresented: $showTestHarness) {
                    SyncTestHarness()
                        .environmentObject(SyncManager.shared)
                }
                .onShake {
                    showTestHarness = true
                }
                #endif
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    // Check app compatibility before sync
                    let compatStatus = await AppCompatManager.shared.checkCompatibility()
                    if compatStatus.isBlocked {
                        // TODO: Show force update alert
                        debugLog.log("App version incompatible: \(AppCompatManager.shared.statusMessage)", category: .error)
                        return
                    }

                    await SyncManager.shared.sync()
                    await SyncManager.shared.startListening()
                }
            } else if newPhase == .background {
                Task {
                    await SyncManager.shared.stopListening()
                }
            }
        }
    }
}
