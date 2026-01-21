//
//  GlobalFloatingButtons.swift
//  Dispatch
//
//  Persistent floating buttons for filter and quick entry (iPhone only).
//  iPad uses toolbar FilterMenu + floating FAB instead.
//

import SwiftUI

// MARK: - GlobalFloatingButtons

/// Global floating buttons that persist during navigation on iPhone.
/// - Left: Filter button (tap to cycle audience)
/// - Right: FAB for quick entry
///
/// iPhone only (by device idiom, not size class).
/// iPad gets a toolbar FilterMenu + separate FAB overlay in ContentView.
struct GlobalFloatingButtons: View {

  // MARK: Internal

  var body: some View {
    #if os(iOS)
    // Only show on iPhone (by idiom, not size class)
    // iPad in Split View can be .compact but shouldn't show floating filter
    if isPhone {
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Spacer doesn't block touches
        .safeAreaInset(edge: .bottom, spacing: 0) {
          floatingButtonsContent
            .padding(.horizontal, DS.Spacing.floatingButtonMargin) // 20pt
            .padding(.bottom, DS.Spacing.floatingButtonBottomInset) // 24pt
        }
        .opacity(shouldHideButtons ? 0 : 1)
        .offset(y: shouldHideButtons ? 12 : 0)
        .allowsHitTesting(!shouldHideButtons)
        .animation(.easeInOut(duration: 0.2), value: shouldHideButtons)
    }
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState

  /// Environment key set by SettingsScreen wrapper to hide buttons
  @Environment(\.globalButtonsHidden) private var environmentHidden

  /// Single source of truth for button visibility.
  /// Combines environment-based hiding (SettingsScreen) with state-based hiding (keyboard, modals).
  private var shouldHideButtons: Bool {
    environmentHidden || overlayState.isOverlayHidden
  }

  #if os(iOS)
  /// INTENTIONALLY uses device idiom, NOT size class.
  /// Rationale: iPad has different UI patterns (toolbar FilterMenu + separate FAB overlay)
  /// regardless of its current size class. Even when iPad is in compact Split View mode,
  /// it should NOT show iPhone-style floating buttons - it uses its own UI paradigm.
  /// This is a device capability check, not a layout adaptation.
  private var isPhone: Bool {
    UIDevice.current.userInterfaceIdiom == .phone
  }

  @ViewBuilder
  private var floatingButtonsContent: some View {
    HStack(alignment: .bottom) {
      // Filter Button (left) - only show when appropriate
      if lensState.showFilterButton {
        FloatingFilterButton(audience: $lensState.audience)
      }

      Spacer()

      // FAB (right) - always visible
      FloatingActionButton {
        appState.sheetState = .quickEntry(type: nil)
      }
    }
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
  .environmentObject(AppOverlayState(mode: .preview))
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
  .environmentObject(AppOverlayState(mode: .preview))
}
#endif
