//
//  SyncCoordinator.swift
//  Dispatch
//
//  Created for Dispatch Architecture Unification
//

import SwiftUI
import Supabase
import Network

/// Owner of the application synchronization lifecycle.
/// Manages the `SyncManager` start/stop states based on scene phase and authentication.
/// Designed to be idempotent.
@MainActor
class SyncCoordinator {
    private let syncManager: SyncManager
    private let authManager: AuthManager
    
    // Track internal state to prevent redundant calls
    private var isListening = false
    private var syncTask: Task<Void, Never>?
    
    // Network Monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.dispatch.network")
    private var lastNetworkStatus: NWPath.Status = .unsatisfied
    
    init(syncManager: SyncManager, authManager: AuthManager) {
        self.syncManager = syncManager
        self.authManager = authManager
        
        startNetworkMonitoring()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handleNetworkChange(status: path.status)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func handleNetworkChange(status: NWPath.Status) {
        if status == .satisfied && lastNetworkStatus != .satisfied {
            // Network restored
            if authManager.isAuthenticated {
                print("[SyncCoordinator] Network restored - requesting sync")
                syncManager.requestSync()
            }
        }
        lastNetworkStatus = status
    }
    
    // MARK: - Handlers
    
    /// Called by AppState or DispatchApp when ScenePhase changes
    func handle(scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            startLifecycle()
        case .background, .inactive:
            stopLifecycle()
        @unknown default:
            break
        }
    }
    
    /// Called by AppState or DispatchApp when Auth state changes
    func handle(authStatusIsAuthenticated: Bool) {
        if authStatusIsAuthenticated {
            // User just logged in
            startLifecycle()
        } else {
            // User logged out
            stopLifecycle()
            syncManager.updateCurrentUser(nil)
        }
    }
    
    func forceSync() {
        Task {
            await syncManager.sync()
        }
    }
    
    // MARK: - Internal Logic
    
    private func startLifecycle() {
        guard authManager.isAuthenticated else { return }
        
        // 1. Update User Context
        syncManager.updateCurrentUser(authManager.currentUserID)
        
        // 2. Perform Compatibility Check (moved from old DispatchApp logic)
        Task {
            let compatStatus = await AppCompatManager.shared.checkCompatibility()
            if compatStatus.isBlocked {
                print("[SyncCoordinator] App version blocked: \(AppCompatManager.shared.statusMessage)")
                return
            }
            
            // 3. Initial Sync
            await syncManager.sync()
            
            // 4. Start Realtime Listening
            if !isListening {
                await syncManager.startListening()
                isListening = true
            }
        }
    }
    
    private func stopLifecycle() {
        // Cancel any in-flight syncs if possible (SyncManager doesn't expose cancellation token yet, but we can stop listening)
        
        if isListening {
            Task {
                await syncManager.stopListening()
                isListening = false
            }
        }
    }
}
