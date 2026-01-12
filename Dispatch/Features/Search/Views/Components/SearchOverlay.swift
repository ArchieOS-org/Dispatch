//
//  SearchOverlay.swift
//  Dispatch
//
//  Main search overlay container with backdrop and modal panel
//  Created by Claude on 2025-12-18.
//

import SwiftData
import SwiftUI

// MARK: - SearchOverlay

/// A full-screen search overlay with dimmed backdrop and floating modal.
///
/// **Layout:**
/// - Dimmed backdrop (tappable to dismiss)
/// - Modal panel respects the device safe area (Dynamic Island / notch)
/// - Floating modal panel with:
///   - Search bar (auto-focused)
///   - Results list (sectioned by type)
///
/// **Animations:**
/// - Spring animation for modal appearance
/// - Respects `accessibilityReduceMotion`
///
/// **Navigation:**
/// - Selecting a result dismisses the overlay and triggers navigation
/// - Navigation is deferred to prevent "push while presenting" issues
///
/// **Focus & Overlay Management:**
/// - Owns its own `@FocusState` for keyboard control
/// - Registers `.searchOverlay` reason with `AppOverlayState` on appear
/// - Clears focus and overlay reason in `dismiss()` (suspenders) + `onDisappear` (belt)
struct SearchOverlay: View {

  // MARK: Internal

  @Binding var isPresented: Bool
  @Binding var searchText: String

  var onSelectResult: (SearchResult) -> Void

  var body: some View {
    ZStack {
      // Backdrop - ignores safe area for full-screen dim
      backdrop
        .ignoresSafeArea()

      // Modal panel - respects safe area (stays below Dynamic Island / notch)
      VStack(spacing: 0) {
        modalContent
          .frame(maxWidth: DS.Spacing.searchModalMaxWidth)
          .background(DS.Colors.Background.groupedSecondary)
          .cornerRadius(DS.Spacing.searchModalRadius)
          .dsShadow(DS.Shadows.searchOverlay)
          .padding(.horizontal, DS.Spacing.searchModalPadding)
          .padding(.top, DS.Spacing.lg)

        Spacer()
      }
    }
    // Phase 1: Visual fade-out (immediate)
    .opacity(isDismissing ? 0 : 1)
    .animation(.easeOut(duration: 0.2), value: isDismissing)
    .allowsHitTesting(!isDismissing)
    .transition(.opacity)
    .onAppear {
      // Register overlay reason immediately
      overlayState.hide(reason: .searchOverlay)
    }
    .task {
      // Wait for text input system to fully initialize before focusing
      // iOS text input requires the view hierarchy to stabilize and the
      // RTIInputSystemSession to be established before focus can be set safely.
      // 250ms allows for: view layout (1 frame ~16ms) + text system init (~100-150ms) + buffer
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, !isDismissing else { return }
      isFocused = true
    }
    .onDisappear {
      // Belt: ensure reason is cleared even if dismiss() was bypassed
      overlayState.show(reason: .searchOverlay)
    }
    // Phase 2: Wait for keyboard to finish hiding before removing from hierarchy
    .onChange(of: overlayState.activeReasons) { _, reasons in
      // If we're dismissing and keyboard reason is now cleared, finalize
      if isDismissing && !reasons.contains(.keyboard) {
        finalizeDismiss()
      }
    }
  }

  // MARK: Private

  @FocusState private var isFocused: Bool
  @EnvironmentObject private var overlayState: AppOverlayState

  /// Phase 1 state: overlay is visually fading out
  @State private var isDismissing = false

  /// Stored result for deferred navigation
  @State private var pendingResult: SearchResult?

  /// Fallback dismiss ID to prevent stale timeouts
  @State private var dismissID: UUID?

  @Query(sort: \TaskItem.title)
  private var tasks: [TaskItem]
  @Query(sort: \Activity.title)
  private var activities: [Activity]
  @Query(sort: \Listing.address)
  private var listings: [Listing]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Filter out deleted items
  private var activeTasks: [TaskItem] {
    tasks.filter { $0.status != .deleted }
  }

  private var activeActivities: [Activity] {
    activities.filter { $0.status != .deleted }
  }

  private var activeListings: [Listing] {
    listings.filter { $0.status != .deleted }
  }

  private var backdrop: some View {
    DS.Colors.searchScrim
      .onTapGesture {
        dismiss()
      }
      .accessibilityLabel("Dismiss search")
      .accessibilityAddTraits(.isButton)
  }

  private var modalContent: some View {
    VStack(spacing: 0) {
      // Search bar with external focus binding
      SearchBar(text: $searchText, externalFocus: $isFocused) {
        dismiss()
      }

      Divider()

      // Results list
      SearchResultsList(
        searchText: searchText,
        tasks: activeTasks,
        activities: activeActivities,
        listings: activeListings,
        onSelectResult: { result in
          selectResult(result)
        }
      )
      .frame(maxHeight: 400)
    }
  }

  private func dismiss() {
    guard !isDismissing else { return }

    // Phase 1: Clear focus (keyboard starts hiding) + visual fade
    isFocused = false
    overlayState.show(reason: .searchOverlay)
    isDismissing = true

    // If keyboard isn't active, finalize immediately
    #if os(iOS)
    if !overlayState.isReasonActive(.keyboard) {
      finalizeDismiss()
    } else {
      // Fallback timeout in case notification is missed
      let currentDismissID = UUID()
      dismissID = currentDismissID
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
        guard isDismissing, dismissID == currentDismissID else { return }
        finalizeDismiss()
      }
    }
    #else
    finalizeDismiss()
    #endif
  }

  private func selectResult(_ result: SearchResult) {
    guard !isDismissing else { return }

    // Phase 1: Clear focus (keyboard starts hiding) + visual fade
    isFocused = false
    overlayState.show(reason: .searchOverlay)
    isDismissing = true
    pendingResult = result

    // If keyboard isn't active, finalize immediately
    #if os(iOS)
    if !overlayState.isReasonActive(.keyboard) {
      finalizeDismiss()
    } else {
      // Fallback timeout in case notification is missed
      let currentDismissID = UUID()
      dismissID = currentDismissID
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
        guard isDismissing, dismissID == currentDismissID else { return }
        finalizeDismiss()
      }
    }
    #else
    finalizeDismiss()
    #endif
  }

  private func finalizeDismiss() {
    let result = pendingResult
    pendingResult = nil
    dismissID = nil
    searchText = ""

    // Phase 2: Actually remove from hierarchy
    isPresented = false

    // Trigger navigation if we had a pending result
    if let result {
      DispatchQueue.main.async {
        onSelectResult(result)
      }
    }
  }
}

// MARK: - Preview

#if DEBUG

private enum SearchOverlayPreviewData {
  static func seededContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskItem.self, Activity.self, Listing.self, configurations: config)
    let context = ModelContext(container)

    // Seed standard data if available
    PreviewDataFactory.seed(context)

    // Add deterministic items that match a sample query
    let listing = (try? context.fetch(FetchDescriptor<Listing>()).first)

    let task1 = TaskItem(
      title: "Fix Broken Window",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      claimedBy: PreviewDataFactory.bobID,
      listingId: listing?.id
    )
    task1.syncState = .synced

    let task2 = TaskItem(
      title: "Window Measurements",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      claimedBy: PreviewDataFactory.bobID,
      listingId: listing?.id
    )
    task2.syncState = .synced

    let activity1 = Activity(
      title: "Window inspection call",
      type: .call,
      declaredBy: PreviewDataFactory.aliceID,
      claimedBy: PreviewDataFactory.bobID,
      listingId: listing?.id
    )
    activity1.syncState = .synced

    context.insert(task1)
    context.insert(task2)
    context.insert(activity1)

    try? context.save()
    return container
  }
}

private struct SearchOverlayPreviewHost: View {
  @State var isPresented: Bool
  @State var searchText: String

  var body: some View {
    ZStack {
      Color.blue.opacity(0.2)
        .ignoresSafeArea()

      if isPresented {
        SearchOverlay(
          isPresented: $isPresented,
          searchText: $searchText,
          onSelectResult: { _ in }
        )
      }
    }
    .environmentObject(AppOverlayState(mode: .preview))
  }
}

#Preview("Search Overlay · Empty") {
  SearchOverlayPreviewHost(isPresented: true, searchText: "")
    .modelContainer(for: [TaskItem.self, Activity.self, Listing.self], inMemory: true)
}

#Preview("Search Overlay · With Results") {
  SearchOverlayPreviewHost(isPresented: true, searchText: "win")
    .modelContainer(SearchOverlayPreviewData.seededContainer())
}

#endif
