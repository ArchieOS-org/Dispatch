import SwiftUI

// MARK: - NavigationPopover

/// The entire dropdown panel containing search + navigation list.
/// Unifies "Quick Find" navigation and "Search" results.
///
/// **Focus Management:**
/// - Owns its own `@FocusState` for keyboard control
/// - Auto-focuses the search field after popover animation completes
/// - Passes external focus binding to SearchBar for proper text input
struct NavigationPopover: View {

  // MARK: Lifecycle

  init(
    searchText: Binding<String>,
    isPresented: Binding<Bool>,
    searchViewModel: SearchViewModel,
    currentTab: AppTab,
    onNavigate: @escaping (AppTab) -> Void,
    onSelectResult: @escaping (SearchResult) -> Void
  ) {
    _searchText = searchText
    _isPresented = isPresented
    self.searchViewModel = searchViewModel
    self.currentTab = currentTab
    self.onNavigate = onNavigate
    self.onSelectResult = onSelectResult
  }

  // MARK: Internal

  @Binding var searchText: String
  @Binding var isPresented: Bool

  let searchViewModel: SearchViewModel
  let currentTab: AppTab
  let onNavigate: (AppTab) -> Void
  let onSelectResult: (SearchResult) -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Unified Search Bar with external focus binding
      SearchBar(
        text: searchTextBinding,
        externalFocus: $searchFieldFocused,
        showCancelButton: false,
        onCancel: {
          searchText = ""
        }
      )
      .padding(.horizontal, DS.Spacing.searchModalPadding)
      .padding(.top, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.sm)

      Divider()

      // Content Switching - uses instant search
      Group {
        if searchText.isEmpty {
          navigationList
        } else {
          InstantSearchResultsList(
            searchViewModel: searchViewModel,
            onSelectResult: { result in
              handleSearchResultSelection(result)
            }
          )
        }
      }
      .frame(height: 350)
    }

    .frame(width: 320)
    .background(DS.Colors.Background.groupedSecondary)
    .clipShape(RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium))
    .dsShadow(DS.Shadows.searchOverlay)
    .overlay(
      RoundedRectangle(cornerRadius: DS.Spacing.radiusMedium)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
    .defaultFocus($searchFieldFocused, true)
  }

  // MARK: Private

  /// Focus state for the search field - enables immediate typing
  @FocusState private var searchFieldFocused: Bool

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

  private var navigationList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // Navigation Items (matches iOS Quick Jump)
        let items: [SearchResult] = [
          .navigation(title: "My Workspace", icon: "briefcase", tab: .workspace, badgeCount: nil),
          .navigation(title: "Listings", icon: DS.Icons.Entity.listing, tab: .listings, badgeCount: nil),
          .navigation(title: "Properties", icon: DS.Icons.Entity.property, tab: .properties, badgeCount: nil),
          .navigation(title: "Realtors", icon: DS.Icons.Entity.realtor, tab: .realtors, badgeCount: nil)
        ]

        ForEach(items) { item in
          Button {
            handleSearchResultSelection(item)
          } label: {
            SearchResultRow(result: item)
          }
          .buttonStyle(.plain)

          if item.id != items.last?.id {
            Divider()
              .padding(.leading, DS.Spacing.lg + DS.Spacing.avatarMedium + DS.Spacing.md)
          }
        }
      }
    }
  }

  private func handleSearchResultSelection(_ result: SearchResult) {
    // Dismiss popover
    isPresented = false
    searchText = ""

    // Use callback instead of notification
    onSelectResult(result)
  }
}

// MARK: - NavigationPopoverPreviewWrapper

private struct NavigationPopoverPreviewWrapper: View {
  @State private var searchText: String = ""
  @State private var isPresented: Bool = true
  @StateObject private var searchViewModel = SearchViewModel()

  var body: some View {
    NavigationPopover(
      searchText: $searchText,
      isPresented: $isPresented,
      searchViewModel: searchViewModel,
      currentTab: .workspace,
      onNavigate: { _ in },
      onSelectResult: { _ in }
    )
    .padding()
  }
}

#Preview {
  NavigationPopoverPreviewWrapper()
}
