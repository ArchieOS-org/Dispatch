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
    .transition(.opacity)
  }

  // MARK: Private

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
      // Search bar
      SearchBar(text: $searchText) {
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
    if reduceMotion {
      isPresented = false
      searchText = ""
    } else {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isPresented = false
      }
      searchText = ""
    }
  }

  private func selectResult(_ result: SearchResult) {
    // Dismiss overlay first
    if reduceMotion {
      isPresented = false
    } else {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isPresented = false
      }
    }
    searchText = ""

    // Defer navigation to next run loop to avoid "push while presenting"
    DispatchQueue.main.async {
      onSelectResult(result)
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
