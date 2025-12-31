//
//  SyncNowToolbar.swift
//  Dispatch
//
//  Reusable toolbar modifier with sync button and keyboard shortcut
//  Created by Claude on 2025-12-18.
//

import SwiftUI

/// A view modifier that adds a "Sync now" toolbar button.
///
/// Replaces pull-to-refresh with an explicit sync action:
/// - iOS/iPad: Toolbar button in trailing position with ⌘R keyboard shortcut
/// - macOS: No toolbar button (Cmd+R handled via Commands in DispatchApp.swift,
///          top bar is empty for Things 3-style bottom toolbar)
///
/// Usage:
/// ```swift
/// NavigationStack {
///     MyView()
/// }
/// .syncNowToolbar()
/// ```
struct SyncNowToolbarModifier: ViewModifier {
    @EnvironmentObject private var syncManager: SyncManager

    func body(content: Content) -> some View {
        #if os(macOS)
        // macOS: No toolbar button - Cmd+R is in menu bar, top bar should be empty
        content
        #else
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                syncButton
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        #endif
    }

    #if os(iOS)
    private var syncButton: some View {
        Button {
            Task {
                await syncManager.sync()
            }
        } label: {
            if syncManager.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(syncManager.isSyncing)
        .accessibilityLabel("Sync now")
        .accessibilityHint("Synchronizes your data with the server")
    }
    #endif
}

extension View {
    /// Adds a "Sync now" toolbar button to the view.
    ///
    /// - Note: Requires `SyncManager` to be in the environment.
    func syncNowToolbar() -> some View {
        modifier(SyncNowToolbarModifier())
    }
}

// MARK: - Preview

#Preview("Sync Now Toolbar") {
    NavigationStack {
        Text("Content")
            .navigationTitle("Test")
    }
    .syncNowToolbar()
    .environmentObject(SyncManager(mode: .preview))
}
