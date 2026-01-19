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
  @Environment(\.fabContext) private var fabContext

  /// Tracks whether the FAB menu is currently open (for hide animation)
  @State private var isMenuOpen = false

  /// Single source of truth for button visibility
  private var shouldHideButtons: Bool {
    overlayState.isOverlayHidden
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
      if lensState.showFilterButton {
        FloatingFilterButton(audience: $lensState.audience)
      }

      Spacer()

      // FAB (right) - context-aware
      fabButton
    }
  }

  /// Context-aware FAB: direct action for single-option contexts, Menu for multi-option contexts
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

    case .workspace:
      // Multi-option: Invisible Menu overlay pattern to avoid UIKit rectangular highlight artifact
      fabVisual
        .overlay {
          Menu {
            Button {
              appState.sheetState = .quickEntry(type: .task)
            } label: {
              Label("New Task", systemImage: DS.Icons.Entity.task)
            }
            Button {
              appState.sheetState = .quickEntry(type: .activity)
            } label: {
              Label("New Activity", systemImage: DS.Icons.Entity.activity)
            }
            Button {
              appState.sheetState = .addListing()
            } label: {
              Label("New Listing", systemImage: DS.Icons.Entity.listing)
            }
          } label: {
            Color.clear
              .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
              .contentShape(Circle())
          }
          .menuIndicator(.hidden)
        }

    case .listingDetail(let listingId):
      // Multi-option: Invisible Menu overlay pattern to avoid UIKit rectangular highlight artifact
      fabVisual
        .overlay {
          Menu {
            Button {
              appState.sheetState = .quickEntry(type: .task, preSelectedListingId: listingId)
            } label: {
              Label("New Task", systemImage: DS.Icons.Entity.task)
            }
            Button {
              appState.sheetState = .quickEntry(type: .activity, preSelectedListingId: listingId)
            } label: {
              Label("New Activity", systemImage: DS.Icons.Entity.activity)
            }
          } label: {
            Color.clear
              .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
              .contentShape(Circle())
          }
          .menuIndicator(.hidden)
        }

    case .realtor(let realtorId):
      // Multi-option: Invisible Menu overlay pattern to avoid UIKit rectangular highlight artifact
      fabVisual
        .overlay {
          Menu {
            Button {
              appState.sheetState = .addProperty(forRealtorId: realtorId)
            } label: {
              Label("New Property", systemImage: DS.Icons.Entity.property)
            }
            Button {
              appState.sheetState = .addListing(forRealtorId: realtorId)
            } label: {
              Label("New Listing", systemImage: DS.Icons.Entity.listing)
            }
          } label: {
            Color.clear
              .frame(width: DS.Spacing.floatingButtonSizeLarge, height: DS.Spacing.floatingButtonSizeLarge)
              .contentShape(Circle())
          }
          .menuIndicator(.hidden)
        }
    }
  }

  /// Visual representation of FAB (used as Menu label for multi-option contexts)
  /// Uses Circle() as root view to ensure circular bounds propagate to Menu's internal button wrapper.
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
