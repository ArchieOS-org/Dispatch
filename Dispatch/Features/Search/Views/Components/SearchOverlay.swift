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
///   - Search bar (auto-focused via defaultFocus)
///   - Results list (sectioned by type)
///
/// **Focus Management (Framework-Correct Pattern):**
/// - Uses `defaultFocus` modifier for instant focus when view appears
/// - View is conditionally rendered in parent (standard `if` statement)
/// - No delays needed - SwiftUI handles focus timing automatically
/// - Clean view lifecycle enables proper keyboard/focus coordination
///
/// **Navigation:**
/// - Selecting a result dismisses overlay and triggers navigation immediately
/// - No artificial delays - view removal is instant
///
/// **Instant Search (Optional):**
/// - When searchViewModel is provided, uses background-indexed instant search
/// - Falls back to legacy filtering when searchViewModel is nil
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
  ///   - searchViewModel: Optional instant search ViewModel (uses legacy filtering if nil)
  ///   - tasks: Pre-fetched active tasks from parent (fallback for legacy search)
  ///   - activities: Pre-fetched active activities from parent (fallback for legacy search)
  ///   - listings: Pre-fetched active listings from parent (fallback for legacy search)
  ///   - onSelectResult: Callback when user selects a search result
  init(
    isPresented: Binding<Bool>,
    searchText: Binding<String>,
    searchViewModel: SearchViewModel? = nil,
    tasks: [TaskItem],
    activities: [Activity],
    listings: [Listing],
    onSelectResult: @escaping (SearchResult) -> Void
  ) {
    _isPresented = isPresented
    _searchText = searchText
    self.searchViewModel = searchViewModel
    self.tasks = tasks
    self.activities = activities
    self.listings = listings
    self.onSelectResult = onSelectResult
  }

  // MARK: Internal

  @Binding var isPresented: Bool
  @Binding var searchText: String

  /// Optional instant search ViewModel - when nil, falls back to legacy filtering
  let searchViewModel: SearchViewModel?

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
    // Use defaultFocus for instant focus when view appears (framework-correct pattern)
    // No delays needed - SwiftUI handles keyboard timing automatically
    .defaultFocus($isFocused, true)
    .onAppear {
      // Register overlay reason (hides GlobalFloatingButtons)
      overlayState.hide(reason: .searchOverlay)
    }
    .onDisappear {
      // Clean up overlay state when view is removed from hierarchy
      overlayState.show(reason: .searchOverlay)
    }
  }

  // MARK: Private

  @FocusState private var isFocused: Bool
  @EnvironmentObject private var overlayState: AppOverlayState

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
      SearchBar(text: searchTextBinding, externalFocus: $isFocused) {
        dismiss()
      }

      Divider()

      // Results list - uses instant search if ViewModel is available
      if let viewModel = searchViewModel {
        InstantSearchResultsList(
          searchViewModel: viewModel,
          onSelectResult: { result in
            selectResult(result)
          }
        )
        .frame(maxHeight: 400)
      } else {
        // Legacy search fallback
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
  }

  /// Search text binding that bridges to SearchViewModel when available
  private var searchTextBinding: Binding<String> {
    if let viewModel = searchViewModel {
      Binding(
        get: { searchText },
        set: { newValue in
          searchText = newValue
          viewModel.onQueryChange(newValue)
        }
      )
    } else {
      $searchText
    }
  }

  private func dismiss() {
    // Clear focus first (triggers keyboard dismissal)
    isFocused = false
    searchText = ""
    // Remove from hierarchy - parent controls via isPresented binding
    isPresented = false
  }

  private func selectResult(_ result: SearchResult) {
    // Clear focus and dismiss
    isFocused = false
    searchText = ""
    isPresented = false
    // Trigger navigation immediately - no delay needed with clean view lifecycle
    onSelectResult(result)
  }
}

// MARK: - Preview

#if DEBUG

private enum SearchOverlayPreviewData {
  static func seededContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
      container = try ModelContainer(for: TaskItem.self, Activity.self, Listing.self, configurations: config)
    } catch {
      fatalError("Failed to create Preview ModelContainer: \(error)")
    }
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

  // MARK: Internal

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
          tasks: activeTasks,
          activities: activeActivities,
          listings: activeListings,
          onSelectResult: { _ in }
        )
      }
    }
    .environmentObject(AppOverlayState(mode: .preview))
  }

  // MARK: Private

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
