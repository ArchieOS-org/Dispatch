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
      ActivityTemplate.self,
      ListingGeneratorDraft.self
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
    WindowGroup(id: "main") {
      // WindowContentView holds per-window @State (WindowUIState on macOS)
      // SwiftUI creates new storage for each window instance
      WindowContentView(appState: appState, showTestHarness: $showTestHarness)
        // Inject Brain & Core Services globally (shared across windows)
        .environmentObject(appState)
        .environmentObject(appState.authManager)
        .environmentObject(SyncManager.shared)
        .onOpenURL { url in
          appState.authManager.handleRedirect(url)
        }
    }
    .modelContainer(sharedModelContainer)
    #if os(macOS)
      .frame(minWidth: DS.Spacing.windowMinWidth, minHeight: DS.Spacing.windowMinHeight)
      .defaultSize(width: DS.Spacing.windowDefaultWidth, height: DS.Spacing.windowDefaultHeight)
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

  /// Configures navigation bar appearance to ensure consistent title colors.
  ///
  /// The primary fix for navigation title color issues during interactive back gestures
  /// is architectural: .tint() is applied ONLY to innerContent/leaf views, not to
  /// container views that wrap navigation modifiers. This prevents the tint environment
  /// from affecting navigation bar elements during gesture state restoration.
  ///
  /// Key points:
  /// - StandardScreen applies .tint() to innerContent (inside ScrollView, away from nav bar)
  /// - AppDestinationsModifier does NOT apply .tint() (destinations use StandardScreen)
  /// - Views outside StandardScreen (ListingGeneratorView) apply tint to their layouts
  /// - Auth views (LoginView, OnboardingLoadingView) apply tint at ZStack level (no nav bar)
  ///
  /// This UIKit configuration provides additional defense-in-depth by
  /// setting explicit title colors that persist during gesture state restoration.
  private func configureNavigationBarAppearance() {
    #if os(iOS)
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()

    // Explicit title colors - ensures titles use label color even during transitions
    appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

    /// Configure button appearance separately from title
    let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
    buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.tintColor]
    appearance.buttonAppearance = buttonAppearance
    appearance.backButtonAppearance = buttonAppearance
    appearance.doneButtonAppearance = buttonAppearance

    /// Apply to all navigation bar appearance states
    let navBar = UINavigationBar.appearance()
    navBar.standardAppearance = appearance
    navBar.scrollEdgeAppearance = appearance
    navBar.compactAppearance = appearance
    if #available(iOS 15.0, *) {
      navBar.compactScrollEdgeAppearance = appearance
    }

    // Explicit tintColor for back button icons
    navBar.tintColor = UIColor.tintColor
    #endif
  }

}
