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
        .opacity(appState.overlayState != .none ? 0 : 1)
        .offset(y: appState.overlayState != .none ? 12 : 0)
        .allowsHitTesting(appState.overlayState == .none)
        .animation(.easeInOut(duration: 0.2), value: appState.overlayState)
    }
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var appState: AppState

  #if os(iOS)
  /// Use idiom, not size class - iPad in Split View can be .compact
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
