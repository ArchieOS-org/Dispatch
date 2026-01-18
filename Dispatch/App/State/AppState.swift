//
//  AppState.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import Combine
import OSLog
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - AppState

/// The central "Brain" of the application.
/// Owns high-level state, routing, and command handling.
@MainActor
final class AppState: ObservableObject {

  // MARK: Lifecycle

  init(mode: RunMode = .live) {
    self.mode = mode
    authManager = AuthManager.shared
    syncCoordinator = SyncCoordinator(syncManager: SyncManager.shared, authManager: AuthManager.shared)

    // Enforcement: Only attach listeners in Live mode
    if mode == .live {
      attachListeners()
    }
  }

  // MARK: Internal

  enum RunMode {
    case live
    case preview
  }

  enum OverlayState: Equatable {
    case none
    case search(initialText: String?) // Canonical Intent
    case settings

    /// Returns true if the overlay state is search (regardless of initial text)
    var isSearch: Bool {
      if case .search = self { return true }
      return false
    }
  }

  enum SheetState: Equatable, Identifiable {
    case none
    case quickEntry(type: QuickEntryItemType?)
    case addListing
    case addRealtor

    // MARK: Internal

    var id: String {
      switch self {
      case .none: "none"
      case .quickEntry: "quickEntry"
      case .addListing: "addListing"
      case .addRealtor: "addRealtor"
      }
    }

    // MARK: - Equatable conformance for associated values

    static func ==(lhs: SheetState, rhs: SheetState) -> Bool {
      switch (lhs, rhs) {
      case (.none, .none):
        true
      case (.quickEntry(let l), .quickEntry(let r)):
        l == r
      case (.addListing, .addListing):
        true
      case (.addRealtor, .addRealtor):
        true
      default:
        false
      }
    }
  }

  let mode: RunMode

  // Optional because in preview mode they might not be initialized or valid
  // However, keeping them non-optional for now to avoid massive churn,
  // but they will be dormant in preview.
  let syncCoordinator: SyncCoordinator
  let authManager: AuthManager

  @Published var router = AppRouter()

  @Published var overlayState = OverlayState.none

  @Published var lensState = LensState()

  @Published var sheetState = SheetState.none

  /// Returns a binding suitable for .sheet(item:)
  /// handles the conversion between internal .none state and optional nil
  var sheetBinding: Binding<SheetState?> {
    Binding<SheetState?>(
      get: { [weak self] in
        guard let self else { return nil }
        return sheetState == .none ? nil : sheetState
      },
      set: { [weak self] newValue in
        self?.sheetState = newValue ?? .none
      }
    )
  }

  func dispatch(_ command: AppCommand) {
    Self.logger.debug("Dispatching command: \(String(describing: command))")

    switch command {
    // MARK: - Destination Selection (iPad/macOS)

    case .userSelectedDestination(let destination):
      router.userSelectDestination(destination)

    case .setSelectedDestination(let destination):
      router.setSelectedDestination(destination)

    // MARK: - Tab Selection (legacy wrappers - bridge to destination-based)

    case .userSelectedTab(let tab):
      router.userSelectDestination(.tab(tab))

    case .setSelectedTab(let tab):
      router.setSelectedDestination(.tab(tab))

    // MARK: - iPad/macOS Navigation (per-destination stacks)

    case .navigateTo(let route, let destination):
      router.navigate(to: route, on: destination)

    case .setPath(let path, let destination):
      router.paths[destination] = path

    case .popToRoot(let destination):
      router.popToRoot(for: destination)

    // MARK: - iPhone Navigation (single stack)

    case .phoneNavigateTo(let route):
      router.phoneNavigate(to: route)

    case .setPhonePath(let path):
      router.phonePath = path

    case .phonePopToRoot:
      router.phonePopToRoot()

    // MARK: - Legacy Navigation (for backwards compatibility)

    case .navigate(let route):
      // Legacy: navigate on current tab (iPad/macOS) or phone path (iPhone)
      // For now, use phone path as default since most existing code is iPhone-oriented
      router.phoneNavigate(to: route)

    case .selectTab(let tab):
      // Legacy: map to userSelectedTab (maintains old behavior)
      router.userSelectTab(tab)

    case .newItem:
      // Context-aware creation based on current destination
      switch router.selectedDestination.asTab ?? .workspace {
      case .properties:
        // TODO: Add property creation sheet when implemented
        break
      case .listings:
        sheetState = .addListing
      case .realtors:
        sheetState = .addRealtor
      case .settings:
        // Settings doesn't have a "new item" action
        break
      case .workspace, .search:
        // Default to quick entry for workspace or search
        sheetState = .quickEntry(type: nil) // nil uses default behavior
      }

    case .openSearch(let initialText):
      // Idempotency guard: ignore if already searching or dismissing
      guard case .none = overlayState else { return }
      overlayState = .search(initialText: initialText)

    case .toggleSidebar:
      #if os(macOS)
      NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
      #endif

    case .syncNow:
      // Guarded: Sync only in live mode
      if mode == .live {
        syncCoordinator.forceSync()
      }

    case .filterMine:
      // Navigate to My Workspace tab
      router.userSelectDestination(.tab(.workspace))

    case .deepLink(let url):
      // Parse and route deep link URL
      guard let route = DeepLinkHandler.route(from: url) else {
        Self.logger.warning("Deep link could not be routed: \(url)")
        return
      }
      // Navigate on both iPad/macOS and iPhone paths for consistency
      router.navigate(to: route)
      router.phoneNavigate(to: route)

    case .removeRoute(let route):
      router.removeRoute(route)

    // MARK: - Keyboard Navigation (macOS)

    case .popNavigation:
      // Pop one level from navigation stack (standard macOS Back behavior)
      // On iPad/macOS: pop current destination's stack
      let currentPath = router.paths[router.selectedDestination] ?? []
      if !currentPath.isEmpty {
        router.popLast(for: router.selectedDestination)
      }
      // Also pop phone path for iPhone consistency
      if !router.phonePath.isEmpty {
        router.phonePopLast()
      }

    case .debugSimulateCrash:
      fatalError("Debug Crash Triggered")
    }
  }

  // MARK: Private

  private static let logger = Logger(subsystem: "Dispatch", category: "AppState")

  private var cancellables = Set<AnyCancellable>()

  private func attachListeners() {
    requireLive("Auth/Sync Listeners")

    // Forward ObservableObject signals to AppState to ensure the Root View (DispatchApp) re-evaluates
    authManager.objectWillChange
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &cancellables)

    SyncManager.shared.objectWillChange
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &cancellables)

    // Forward lensState changes so views observing appState.lensState.* update correctly
    // SwiftUI does NOT automatically observe nested ObservableObject changes
    lensState.objectWillChange
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &cancellables)
  }

  /// Strict enforcement: crashes if called in preview mode
  private func requireLive(_ reason: String) {
    precondition(mode == .live, "Side-Effect Violation in Preview Mode: \(reason)")
  }

}
