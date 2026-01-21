//
//  GlobalFloatingButtons.swift
//  Dispatch
//
//  Persistent floating buttons for filter and quick entry (iPhone only).
//  iPad uses toolbar FilterMenu + floating FAB instead.
//
//  Architecture: Pure SwiftUI Menu approach - single button visual per button.
//  No UIKit overlays, no duplicate rendering, no animation timing conflicts.
//

import SwiftUI

// MARK: - FABMenuItem

/// Menu item for FAB context menus (used by GlobalFloatingButtons and iPadContentView)
struct FABMenuItem: Identifiable {
  let id = UUID()
  let title: String
  let icon: String
  let action: () -> Void
}

// MARK: - GlobalFloatingButtons

/// Global floating buttons that persist during navigation on iPhone.
/// - Left: Filter button (tap to cycle audience, long-press for menu)
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
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Spacer doesn't block touches
        .safeAreaInset(edge: .bottom, spacing: 0) {
          floatingButtonsContent
            .padding(.horizontal, DS.Spacing.floatingButtonMargin) // 20pt
            .padding(.bottom, DS.Spacing.floatingButtonBottomInset) // 24pt
        }
    }
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var overlayState: AppOverlayState
  @Environment(\.fabContext) private var fabContext

  /// Other overlay reasons (keyboard, text input, etc.) hide all buttons
  private var shouldHideAllButtons: Bool {
    overlayState.activeReasons.contains { reason in
      switch reason {
      case .fabMenuOpen, .filterMenuOpen:
        false // Menu presentation handled by SwiftUI Menu
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
      // Filter Button (left) - tap cycles, long-press opens menu
      if lensState.showFilterButton {
        filterButton
          .opacity(shouldHideAllButtons ? 0 : 1)
          .offset(y: shouldHideAllButtons ? 12 : 0)
          .allowsHitTesting(!shouldHideAllButtons)
          .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
      }

      Spacer()

      // FAB (right) - context-aware
      fabButton
        .opacity(shouldHideAllButtons ? 0 : 1)
        .offset(y: shouldHideAllButtons ? 12 : 0)
        .allowsHitTesting(!shouldHideAllButtons)
        .animation(.easeInOut(duration: 0.2), value: shouldHideAllButtons)
    }
  }

  /// Filter button with Menu: tap cycles filter, long-press shows all options
  @ViewBuilder
  private var filterButton: some View {
    Menu {
      ForEach(AudienceLens.allCases, id: \.self) { lens in
        Button {
          lensState.audience = lens
        } label: {
          Label(lens.label, systemImage: lens.icon)
        }
      }
    } label: {
      filterButtonVisual
    } primaryAction: {
      // Tap action: cycle to next filter
      lensState.audience = lensState.audience.next
    }
    .sensoryFeedback(.selection, trigger: lensState.audience)
    .accessibilityIdentifier("AudienceFilterButton")
    .accessibilityLabel("Filter: \(lensState.audience.label)")
    .accessibilityHint("Tap to cycle, hold for options")
  }

  /// Visual representation of filter button
  private var filterButtonVisual: some View {
    ZStack {
      // 44pt glass circle, centered in 56pt hit area
      Circle()
        .fill(.ultraThinMaterial)
        .frame(width: DS.Spacing.floatingButtonSize, height: DS.Spacing.floatingButtonSize)
        .dsShadow(DS.Shadows.medium)

      // Icon
      Image(systemName: lensState.audience.icon)
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(lensState.audience == .all ? .primary : lensState.audience.tintColor)
        .font(.system(size: scaledFilterIconSize, weight: .semibold))
    }
    .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
    .contentShape(Circle())
  }

  /// Context-aware FAB: direct action for single-option contexts, Menu for multi-option
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
      // Multi-option: SwiftUI Menu with FAB as label
      fabMenu
    }
  }

  /// FAB with integrated Menu for multi-option contexts
  private var fabMenu: some View {
    Menu {
      ForEach(fabMenuItems) { item in
        Button {
          item.action()
        } label: {
          Label(item.title, systemImage: item.icon)
        }
      }
    } label: {
      fabVisual
    }
    .accessibilityLabel("Create")
    .accessibilityHint("Opens menu with creation options")
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

  /// Visual representation of FAB (used for multi-option contexts)
  /// Uses Circle() as root view to ensure circular bounds.
  private var fabVisual: some View {
    Circle()
      .fill(DS.Colors.accent)
      .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
      .overlay {
        Image(systemName: "plus")
          .font(.system(size: scaledFABIconSize, weight: .semibold))
          .foregroundColor(.white)
      }
      .dsShadow(DS.Shadows.elevated)
      .compositingGroup()
  }

  /// Scaled icon size for FAB (base: 24pt, relative to title3)
  @ScaledMetric(relativeTo: .title3)
  private var scaledFABIconSize: CGFloat = 24

  /// Scaled icon size for filter button (base: 20pt, relative to body)
  @ScaledMetric(relativeTo: .body)
  private var scaledFilterIconSize: CGFloat = 20
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
