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
/// - Right: FAB for quick entry (context-aware)
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
      ZStack {
        Color.clear
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .allowsHitTesting(false) // Spacer doesn't block touches
          .safeAreaInset(edge: .bottom, spacing: 0) {
            floatingButtonsContent
              .padding(.horizontal, DS.Spacing.floatingButtonMargin) // 20pt
              .padding(.bottom, DS.Spacing.floatingButtonBottomInset) // 24pt
          }

        // Custom FAB menu overlay with iOS 26 effects (liquid glass + spring animation)
        FABMenuOverlay(
          isPresented: $showFABMenu,
          items: fabMenuItems
        )

        // Custom filter menu overlay with iOS 26 effects
        FilterMenuOverlay(
          isPresented: $showFilterMenu,
          audience: $lensState.audience
        )
      }
      .onChange(of: showFABMenu) { _, isPresented in
        if isPresented {
          overlayState.hide(reason: .fabMenuOpen)
        } else {
          overlayState.show(reason: .fabMenuOpen)
        }
      }
      .onChange(of: showFilterMenu) { _, isPresented in
        if isPresented {
          overlayState.hide(reason: .filterMenuOpen)
        } else {
          overlayState.show(reason: .filterMenuOpen)
        }
      }
    }
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState
  @Environment(\.fabContext) private var fabContext

  /// Controls FAB menu presentation
  @State private var showFABMenu = false

  /// Controls filter menu presentation
  @State private var showFilterMenu = false

  /// FAB hides when FAB menu is open
  private var shouldHideFAB: Bool {
    overlayState.isReasonActive(.fabMenuOpen)
  }

  /// Filter button hides when filter menu is open
  private var shouldHideFilter: Bool {
    overlayState.isReasonActive(.filterMenuOpen)
  }

  /// Other overlay reasons (keyboard, text input, etc.) hide all buttons
  private var shouldHideAllButtons: Bool {
    overlayState.activeReasons.contains { reason in
      switch reason {
      case .fabMenuOpen, .filterMenuOpen:
        false // Handled independently
      case .textInput, .keyboard, .modal, .searchOverlay, .settingsScreen:
        true
      }
    }
  }

  #if os(iOS)
  /// Use idiom, not size class - iPad in Split View can be .compact
  private var isPhone: Bool {
    UIDevice.current.userInterfaceIdiom == .phone
  }

  @ViewBuilder
  private var floatingButtonsContent: some View {
    HStack(alignment: .bottom) {
      // Filter Button (left) - only show when appropriate
      // Independent visibility: hides only when filter menu open OR global hide reasons
      if lensState.showFilterButton {
        FloatingFilterButton(
          audience: $lensState.audience,
          onLongPress: { showFilterMenu = true }
        )
        .opacity(shouldHideFilter || shouldHideAllButtons ? 0 : 1)
        .offset(y: shouldHideFilter || shouldHideAllButtons ? 12 : 0)
        .allowsHitTesting(!shouldHideFilter && !shouldHideAllButtons)
        .animation(.easeInOut(duration: 0.2), value: shouldHideFilter)
        .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
      }

      Spacer()

      // FAB (right) - context-aware
      // Independent visibility: hides only when FAB menu open OR global hide reasons
      fabButton
        .opacity(shouldHideFAB || shouldHideAllButtons ? 0 : 1)
        .offset(y: shouldHideFAB || shouldHideAllButtons ? 12 : 0)
        .allowsHitTesting(!shouldHideFAB && !shouldHideAllButtons)
        .animation(.easeInOut(duration: 0.2), value: shouldHideFAB)
        .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
    }
  }

  /// Context-aware FAB menu items based on current context
  private var fabMenuItems: [FABMenuItem] {
    switch fabContext {
    case .workspace:
      [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) {
          appState.sheetState = .quickEntry(type: .task)
        },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) {
          appState.sheetState = .quickEntry(type: .activity)
        },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) {
          appState.sheetState = .addListing()
        }
      ]

    case .listingDetail(let listingId):
      [
        FABMenuItem(title: "New Task", icon: DS.Icons.Entity.task) {
          appState.sheetState = .quickEntry(type: .task, preSelectedListingId: listingId)
        },
        FABMenuItem(title: "New Activity", icon: DS.Icons.Entity.activity) {
          appState.sheetState = .quickEntry(type: .activity, preSelectedListingId: listingId)
        }
      ]

    case .realtor(let realtorId):
      [
        FABMenuItem(title: "New Property", icon: DS.Icons.Entity.property) {
          appState.sheetState = .addProperty(forRealtorId: realtorId)
        },
        FABMenuItem(title: "New Listing", icon: DS.Icons.Entity.listing) {
          appState.sheetState = .addListing(forRealtorId: realtorId)
        }
      ]

    case .listingList, .properties:
      // Single-action contexts don't use the menu
      []
    }
  }

  /// Context-aware FAB: direct action for single-option contexts, tap to show custom menu overlay for multi-option
  @ViewBuilder
  private var fabButton: some View {
    switch fabContext {
    case .listingList:
      // Single action: create Listing - direct tap
      FloatingActionButton {
        appState.sheetState = .addListing()
      }

    case .properties:
      // Single action: create Property - direct tap
      FloatingActionButton {
        appState.sheetState = .addProperty()
      }

    case .workspace, .listingDetail, .realtor:
      // Multi-option: tap to show custom menu overlay with iOS 26 effects
      fabVisual
        .onTapGesture {
          showFABMenu = true
        }
    }
  }

  /// Visual representation of FAB (used for multi-option contexts)
  /// Uses Circle() as root view to ensure circular bounds.
  private var fabVisual: some View {
    Circle()
      .fill(DS.Colors.accent)
      .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
      .overlay {
        Image(systemName: "plus")
          .font(.system(size: scaledIconSize, weight: .semibold))
          .foregroundColor(.white)
      }
      .dsShadow(DS.Shadows.elevated)
      .compositingGroup()
  }

  /// Scaled icon size for Dynamic Type support (base: 24pt, relative to title3)
  @ScaledMetric(relativeTo: .title3)
  private var scaledIconSize: CGFloat = 24
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
