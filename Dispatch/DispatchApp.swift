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

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncManager = SyncManager.shared

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

    // Stub removed - SyncManager now observes AuthManager
    
    init() {
        SyncManager.shared.configure(with: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    if syncManager.currentUser != nil {
                        ContentView()
                            .environmentObject(authManager)
                            .environmentObject(syncManager)
                            #if DEBUG
                            .sheet(isPresented: $showTestHarness) {
                                SyncTestHarness()
                                    .environmentObject(SyncManager.shared)
                            }
                            #if os(iOS)
                            .onShake {
                                showTestHarness = true
                            }
                            #endif
                            #endif
                            .configureMacWindow()
                    } else {
                        OnboardingLoadingView()
                    }
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                authManager.handleRedirect(url)
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar) // The native "Things 3" pattern
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Item") {
                    NotificationCenter.default.post(name: .newItem, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!authManager.isAuthenticated)

                Button("Search") {
                    NotificationCenter.default.post(name: .openSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!authManager.isAuthenticated)

                Divider()

                Button("My Tasks") {
                    NotificationCenter.default.post(name: .filterMine, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(!authManager.isAuthenticated)

                Button("Others' Tasks") {
                    NotificationCenter.default.post(name: .filterOthers, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(!authManager.isAuthenticated)

                Button("Unclaimed") {
                    NotificationCenter.default.post(name: .filterUnclaimed, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
            }
            CommandGroup(after: .toolbar) {
                Button("Sync Now") {
                    Task {
                        await SyncManager.shared.sync()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
                .disabled(!authManager.isAuthenticated)
            }
        }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && authManager.isAuthenticated {
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
        // Listen for auth state changes to trigger sync
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    // Update SyncManager with current user
                    // Note: AuthManager runs on MainActor, so we access currentUserID directly
                    SyncManager.shared.updateCurrentUser(authManager.currentUserID)
                    await SyncManager.shared.sync()
                    await SyncManager.shared.startListening()
                }
            } else {
                Task {
                    await SyncManager.shared.stopListening()
                    SyncManager.shared.updateCurrentUser(nil)
                }
            }
        }
    }
}
