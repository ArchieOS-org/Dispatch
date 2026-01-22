//
//  SearchOverlay.swift
//  Dispatch
//
//  Main search overlay container with backdrop and modal panel
//  Created by Claude on 2025-12-18.
//

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
/// **Instant Search:**
/// - Uses background-indexed instant search via SearchViewModel
struct SearchOverlay: View {

  // MARK: Lifecycle

  /// Initialize SearchOverlay with SearchViewModel for instant search.
  ///
  /// - Parameters:
  ///   - isPresented: Binding controlling overlay visibility
  ///   - searchText: Binding to the search query text
  ///   - searchViewModel: SearchViewModel for instant search
  ///   - onSelectResult: Callback when user selects a search result
  init(
    isPresented: Binding<Bool>,
    searchText: Binding<String>,
    searchViewModel: SearchViewModel,
    onSelectResult: @escaping (SearchResult) -> Void
  ) {
    _isPresented = isPresented
    _searchText = searchText
    self.searchViewModel = searchViewModel
    self.onSelectResult = onSelectResult
  }

  // MARK: Internal

  @Binding var isPresented: Bool
  @Binding var searchText: String

  /// SearchViewModel for instant search
  let searchViewModel: SearchViewModel

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

      // Results list - uses instant search
      InstantSearchResultsList(
        searchViewModel: searchViewModel,
        onSelectResult: { result in
          selectResult(result)
        }
      )
      .frame(maxHeight: 400)
    }
  }

  /// Search text binding that bridges to SearchViewModel
  /// Uses Task to defer onQueryChange to next run loop, avoiding "Publishing changes
  /// from within view updates" warnings that cause perceived lag.
  private var searchTextBinding: Binding<String> {
    Binding(
      get: { searchText },
      set: { newValue in
        searchText = newValue
        Task { @MainActor in
          searchViewModel.onQueryChange(newValue)
        }
      }
    )
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

// MARK: - SearchOverlayPreviewHost

#if DEBUG

private struct SearchOverlayPreviewHost: View {
  @State var isPresented: Bool
  @State var searchText: String
  @StateObject var searchViewModel = SearchViewModel()

  var body: some View {
    ZStack {
      Color.blue.opacity(0.2)
        .ignoresSafeArea()

      if isPresented {
        SearchOverlay(
          isPresented: $isPresented,
          searchText: $searchText,
          searchViewModel: searchViewModel,
          onSelectResult: { _ in }
        )
      }
    }
    .environmentObject(AppOverlayState(mode: .preview))
  }
}

#Preview("Search Overlay · Empty") {
  SearchOverlayPreviewHost(isPresented: true, searchText: "")
}

#Preview("Search Overlay · With Query") {
  SearchOverlayPreviewHost(isPresented: true, searchText: "win")
}

#endif
