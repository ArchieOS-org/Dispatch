//
//  AppState.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI
import Combine

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
    
    enum OverlayState: Equatable {
        case none
        case quickFind(initialText: String?)
        case settings
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
            
        case .newItem:
            // TODO: Route to creation sheet or focused input
            // For now, post legacy notification to bridge gap during migration
            NotificationCenter.default.post(name: .newItem, object: nil)
            
        case .openSearch(let initialText):
            overlayState = .quickFind(initialText: initialText)
            // Legacy bridge
            NotificationCenter.default.post(name: .openSearch, object: nil)
            
        case .toggleSidebar:
            // Legacy bridge (NSApp target usually handles this via responder chain, but we can force it)
            NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            
        case .syncNow:
            syncCoordinator.forceSync()
            
        case .filterMine:
            NotificationCenter.default.post(name: .filterMine, object: nil)
        case .filterOthers:
            NotificationCenter.default.post(name: .filterOthers, object: nil)
        case .filterUnclaimed:
            NotificationCenter.default.post(name: .filterUnclaimed, object: nil)
            
        case .debugSimulateCrash:
            fatalError("Debug Crash Triggered")
        }
    }
}
