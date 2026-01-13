//
//  DispatchApp.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-06.
//

import SwiftData
import SwiftUI

@main
struct DispatchApp: App {

  // MARK: Lifecycle

  init() {
    SyncManager.shared.configure(with: sharedModelContainer)
    configureNavigationBarAppearance()
  }

  // MARK: Internal

  /// Check if running in UI test mode via launch argument
  static let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      User.self,
      TaskItem.self,
      Activity.self,
      TaskAssignee.self,
      ActivityAssignee.self,
      Listing.self,
      Note.self,
      Subtask.self,
      StatusChange.self,
      ListingTypeDefinition.self,
      ActivityTemplate.self
    ])
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isUITesting
    )

    do {
      let container = try ModelContainer(
        for: schema,
        configurations: [modelConfiguration]
      )

      // Seed test data when running UI tests
      if isUITesting {
        UITestSeeder.seedIfNeeded(container: container)
      }

      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

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
      }
      .tint(DS.Colors.accent)
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

  // MARK: Private

  @Environment(\.scenePhase) private var scenePhase

  /// The Brain
  @StateObject private var appState = AppState()

  // Legacy: Keep test harness state locally or move to AppState later?
  // Moving to local for now to keep AppState clean of debug UI logic if possible,
  // or we can put it in AppState.overlayState. Let's keep it here for minimal regression.
  #if DEBUG
  @State private var showTestHarness = false
  #endif

  /// Configures navigation bar appearance to prevent title color issues during interactive transitions.
  /// Sets all 4 appearance states so iOS never falls back to tint defaults mid-gesture.
  private func configureNavigationBarAppearance() {
    #if os(iOS)
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()

    // Explicit title colors - don't rely on defaults during interactive gestures
    appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

    let navBar = UINavigationBar.appearance()
    navBar.standardAppearance = appearance
    navBar.scrollEdgeAppearance = appearance
    navBar.compactAppearance = appearance
    if #available(iOS 15.0, *) {
      navBar.compactScrollEdgeAppearance = appearance
    }
    // NOTE: Button tint handled by SwiftUI .tint(DS.Colors.accent) at app root
    #endif
  }

}
