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

  // MARK: Lifecycle

  /// Initialize SearchOverlay with pre-fetched data from parent.
  ///
  /// This pattern (same as QuickEntrySheet) avoids duplicate @Query properties
  /// and ensures data is only fetched once at the ContentView level.
  ///
  /// - Parameters:
  ///   - isPresented: Binding controlling overlay visibility
  ///   - searchText: Binding to the search query text
  ///   - tasks: Pre-fetched active tasks from parent
  ///   - activities: Pre-fetched active activities from parent
  ///   - listings: Pre-fetched active listings from parent
  ///   - onSelectResult: Callback when user selects a search result
  init(
    isPresented: Binding<Bool>,
    searchText: Binding<String>,
    tasks: [TaskItem],
    activities: [Activity],
    listings: [Listing],
    onSelectResult: @escaping (SearchResult) -> Void
  ) {
    self._isPresented = isPresented
    self._searchText = searchText
    self.tasks = tasks
    self.activities = activities
    self.listings = listings
    self.onSelectResult = onSelectResult
  }

  // MARK: Internal

  @Binding var isPresented: Bool
  @Binding var searchText: String

  /// Pre-fetched active tasks from ContentView (no @Query needed)
  let tasks: [TaskItem]
  /// Pre-fetched active activities from ContentView (no @Query needed)
  let activities: [Activity]
  /// Pre-fetched active listings from ContentView (no @Query needed)
  let listings: [Listing]

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
    // Respond to isPresented changes (view is always in hierarchy for stable identity)
    .onChange(of: isPresented) { _, presented in
      if presented {
        // Register overlay reason (hides GlobalFloatingButtons)
        overlayState.hide(reason: .searchOverlay)
        // Reset dismissing state for fresh presentation
        isDismissing = false
        // Focus handled by .task(id:) ONLY - RTI session needs time to establish
      } else {
        // Belt: ensure reason is cleared when dismissed
        overlayState.show(reason: .searchOverlay)
        isFocused = false
      }
    }
    .task(id: isPresented) {
      guard isPresented else { return }
      // Wait for RTIInputSystemSession to establish
      // iOS Remote Text Input requires:
      // 1. View layout completion (~16-32ms)
      // 2. Keyboard infrastructure init
      // 3. IPC session with keyboard process
      // 100ms is safe minimum; 16ms is insufficient
      try? await Task.sleep(for: .milliseconds(100))
      guard !Task.isCancelled, !isDismissing, isPresented else {
        return
      }
      isFocused = true
    }
    // Phase 2: Wait for keyboard to finish hiding before removing from hierarchy
    .onChange(of: overlayState.activeReasons) { _, reasons in
      // If we're dismissing and keyboard reason is now cleared, finalize
      if isDismissing, !reasons.contains(.keyboard) {
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

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        tasks: tasks,
        activities: activities,
        listings: listings,
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
      // Wait for dismiss animation to complete before triggering navigation
      // Prevents NavigationAuthority warnings from overlapping state changes
      // Animation duration is ~200ms; 250ms provides safety margin
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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
      listingId: listing?.id,
      assigneeUserIds: [PreviewDataFactory.bobID]
    )
    task1.syncState = .synced

    let task2 = TaskItem(
      title: "Window Measurements",
      status: .open,
      declaredBy: PreviewDataFactory.aliceID,
      listingId: listing?.id,
      assigneeUserIds: [PreviewDataFactory.bobID]
    )
    task2.syncState = .synced

    let activity1 = Activity(
      title: "Window inspection call",
      declaredBy: PreviewDataFactory.aliceID,
      listingId: listing?.id,
      assigneeUserIds: [PreviewDataFactory.bobID]
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

  @Query private var tasks: [TaskItem]
  @Query private var activities: [Activity]
  @Query private var listings: [Listing]

  private var activeTasks: [TaskItem] {
    tasks.filter { $0.status != .deleted }
  }

  private var activeActivities: [Activity] {
    activities.filter { $0.status != .deleted }
  }

  private var activeListings: [Listing] {
    listings.filter { $0.status != .deleted }
  }

  var body: some View {
    ZStack {
      Color.blue.opacity(0.2)
        .ignoresSafeArea()

      if isPresented {
        SearchOverlay(
          isPresented: $isPresented,
          searchText: $searchText,
          tasks: activeTasks,
          activities: activeActivities,
          listings: activeListings,
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
