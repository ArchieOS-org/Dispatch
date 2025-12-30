//
//  AppState.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

/// The central "Brain" of the application.
/// Owns high-level state, routing, and command handling.
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Dependencies (Owned)
    let syncCoordinator: SyncCoordinator
    let authManager: AuthManager
    
    // MARK: - Navigation State
    @Published var router = AppRouter()
    
    // MARK: - UI State
    @Published var overlayState: OverlayState = .none
    
    // MARK: - Lens State (Filtering)
    @Published var lensState = LensState()
    
    enum OverlayState: Equatable {
        case none
        case quickFind(initialText: String?)
        case settings
    }
    
    // MARK: - Sheet State
    @Published var sheetState: SheetState = .none
    
    enum SheetState: Equatable, Identifiable {
        case none
        case quickEntry(type: QuickEntryItemType?)
        case addListing
        case addRealtor
        
        var id: String {
            switch self {
            case .none: return "none"
            case .quickEntry: return "quickEntry"
            case .addListing: return "addListing"
            case .addRealtor: return "addRealtor"
            }
        }
    }
    
    // MARK: - Init
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        self.authManager = AuthManager.shared
        self.syncCoordinator = SyncCoordinator(syncManager: SyncManager.shared, authManager: AuthManager.shared)
        
        // Forward ObservableObject signals to AppState to ensure the Root View (DispatchApp) re-evaluates
        authManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        SyncManager.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
    
    // MARK: - Command Bus
    
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
            case .listings:
                sheetState = .addListing
            case .realtors:
                sheetState = .addRealtor
            case .workspace, .search:
                // Default to quick entry for workspace or search
                sheetState = .quickEntry(type: nil) // nil uses default behavior
            }
            
        case .openSearch(let initialText):
            overlayState = .quickFind(initialText: initialText)
            
        case .toggleSidebar:
            #if os(macOS)
            NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
            #endif
            
        case .syncNow:
            syncCoordinator.forceSync()
            
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
}
