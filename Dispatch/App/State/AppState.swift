//
//  AppState.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import Combine
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
  }

  enum SheetState: Equatable, Identifiable {
    case none
    case quickEntry(type: QuickEntryItemType?)
    case addListing
    case addRealtor

    var id: String {
      switch self {
      case .none: "none"
      case .quickEntry: "quickEntry"
      case .addListing: "addListing"
      case .addRealtor: "addRealtor"
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
      },
    )
  }

  func dispatch(_ command: AppCommand) {
    print("[AppState] Dispatching command: \(command)")

    switch command {
    case .navigate(let destination):
      router.navigate(to: destination)

    case .popToRoot:
      router.popToRoot()

    case .selectTab(let tab):
      router.selectTab(tab)

    case .newItem:
      // Context-aware creation based on current tab
      switch router.selectedTab {
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
      // TODO: Implement AssignmentFilter in LensState (AudienceLens is for Role, not Assignment)
      // lensState.audience = .me
      break

    case .filterOthers:
      // lensState.audience = .everyone
      break

    case .filterUnclaimed:
      // lensState.audience = .unclaimed
      break

    case .debugSimulateCrash:
      fatalError("Debug Crash Triggered")
    }
  }

  // MARK: Private

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
  }

  /// Strict enforcement: crashes if called in preview mode
  private func requireLive(_ reason: String) {
    precondition(mode == .live, "Side-Effect Violation in Preview Mode: \(reason)")
  }

}
