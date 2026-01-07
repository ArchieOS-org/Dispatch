//
//  SearchOverlay.swift
//  Dispatch
//
//  Main search overlay container with backdrop and modal panel
//  Created by Claude on 2025-12-18.
//

import SwiftData
import SwiftUI

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
        },
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

#Preview("Search Overlay") {
  @Previewable @State var isPresented = true
  @Previewable @State var searchText = ""

  ZStack {
    Color.blue.opacity(0.2)
      .ignoresSafeArea()

    if isPresented {
      SearchOverlay(
        isPresented: $isPresented,
        searchText: $searchText,
        onSelectResult: { result in
          print("Selected: \(result.title)")
        },
      )
    }
  }
  .modelContainer(for: [TaskItem.self, Activity.self, Listing.self], inMemory: true)
}
