//
//  GlobalFloatingButtons.swift
//  Dispatch
//
//  Persistent floating buttons for filter and quick entry (iPhone only)
//

import SwiftUI

/// Global floating buttons that persist during navigation.
/// - Left: Filter button (tap to cycle audience, long-press for menu)
/// - Right: FAB for quick entry
///
/// Hides with animation when text input is focused or keyboard is visible.
struct GlobalFloatingButtons: View {
    @EnvironmentObject private var lensState: LensState
    @EnvironmentObject private var appState: AppState // One Boss

    var body: some View {
        #if os(iOS)
        // Render directly without GeometryReader to avoid layout loops
        VStack {
            Spacer()
            
            HStack {
                // Filter Button (left) - only show on TaskListView
                if lensState.showFilterButton {
                    filterButton
                }

                Spacer()

                // FAB (right)
                FloatingActionButton {
                    appState.sheetState = .quickEntry(type: nil)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg) // Standard bottom padding
        }
        // Animate visibility via opacity + offset
        // Hide if ANY overlay is active (One Boss)
        .opacity(appState.overlayState != .none ? 0 : 1)
        .offset(y: appState.overlayState != .none ? 12 : 0)
        .allowsHitTesting(appState.overlayState == .none)
        .animation(.easeInOut(duration: 0.2), value: appState.overlayState)
        #endif
    }

    // MARK: - Filter Button

    #if os(iOS)
    private var filterButton: some View {
        AudienceFilterButton(
            lens: lensState.audience,
            action: lensState.cycleAudience
        )
    }

    #endif
}

// MARK: - Previews

#if os(iOS)
#Preview("Global Floating Buttons") {
    ZStack {
        DS.Colors.Background.grouped
            .ignoresSafeArea()

        GlobalFloatingButtons()
    }
    .environmentObject(LensState())
    .environmentObject(AppState(mode: .preview))
}

#Preview("Global Floating Buttons - Filtered") {
    let lensState = LensState()
    lensState.audience = .admin

    return ZStack {
        DS.Colors.Background.grouped
            .ignoresSafeArea()

        GlobalFloatingButtons()
    }
    .environmentObject(lensState)
    .environmentObject(AppState(mode: .preview))
}
#endif
