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

    // The Brain
    @StateObject private var appState = AppState()
    
    // Legacy: Keep test harness state locally or move to AppState later?
    // Moving to local for now to keep AppState clean of debug UI logic if possible, 
    // or we can put it in AppState.overlayState. Let's keep it here for minimal regression.
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
    
    init() {
        SyncManager.shared.configure(with: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                ZStack {
                    if appState.authManager.isAuthenticated {
                        if SyncManager.shared.currentUser != nil {
                            AppShellView()
                                .transition(.opacity)
                        } else {
                            OnboardingLoadingView()
                                .transition(.opacity)
                        }
                    } else {
                        LoginView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut, value: appState.authManager.isAuthenticated)
                .animation(.easeInOut, value: SyncManager.shared.currentUser)
            }
            // Inject Brain & Core Services globally
            .environmentObject(appState)
            .environmentObject(appState.authManager)
            .environmentObject(SyncManager.shared)
            
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
            .onOpenURL { url in
                appState.authManager.handleRedirect(url)
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            // Pass the dispatch closure explicitly to avoid Environment lookup issues in menu bar
            DispatchCommands { cmd in
                appState.dispatch(cmd)
            }
        }
        #endif
        // Plumbing: Feed ScenePhase to Coordinator
        .onChange(of: scenePhase) { _, newPhase in
            appState.syncCoordinator.handle(scenePhase: newPhase)
        }
        // Plumbing: Feed Auth changes to Coordinator
        .onChange(of: appState.authManager.isAuthenticated) { _, isAuthenticated in
            appState.syncCoordinator.handle(authStatusIsAuthenticated: isAuthenticated)
        }
    }
}
