
import SwiftData
import SwiftUI

/// The entire dropdown panel containing search + navigation list.
/// Unifies "Quick Find" navigation and "Search" results.
struct NavigationPopover: View {

  // MARK: Lifecycle

  init(
    searchText: Binding<String>,
    isPresented: Binding<Bool>,
    currentTab: AppTab,
    onNavigate: @escaping (AppTab) -> Void,
    onSelectResult: @escaping (SearchResult) -> Void,
  ) {
    _searchText = searchText
    _isPresented = isPresented
    self.currentTab = currentTab
    self.onNavigate = onNavigate
    self.onSelectResult = onSelectResult
  }

  // MARK: Internal

  @Binding var searchText: String
  @Binding var isPresented: Bool

  let currentTab: AppTab
  let onNavigate: (AppTab) -> Void
  let onSelectResult: (SearchResult) -> Void

  // Hardcoded empty arrays removed (Queries active)

  // Hardcoded counts for MVP demo (Navigation List)
  let inboxCount = 4
  let todayCount = 8

  var body: some View {
    VStack(spacing: 0) {
      // Unifed Search Bar (replaces QuickFindField)
      SearchBar(
        text: $searchText,
        showCancelButton: false,
        onCancel: {
          searchText = ""
        },
      )
      .padding(.horizontal, DS.Spacing.searchModalPadding)
      .padding(.top, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.sm)

      Divider()

      // Content Switching
      Group {
        if searchText.isEmpty {
          navigationList
        } else {
          // Search Results (Unified Component)
          SearchResultsList(
            searchText: searchText,
            tasks: activeTasks,
            activities: activeActivities,
            listings: activeListings,
            onSelectResult: { result in
              handleSearchResultSelection(result)
            },
          )
        }
      }
      .frame(height: 350)
    }

    .frame(width: 320)
    .background(DS.Colors.Background.groupedSecondary)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: 20, y: 10)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
  }

  // MARK: Private

  /// Search Data Queries
  @Query(sort: \TaskItem.title)
  private var tasks: [TaskItem]
  @Query(sort: \Activity.title)
  private var activities: [Activity]
  @Query(sort: \Listing.address)
  private var listings: [Listing]

  /// Filtered data for search
  private var activeTasks: [TaskItem] {
    tasks.filter { $0.status != .deleted }
  }

  private var activeActivities: [Activity] {
    activities.filter { $0.status != .deleted }
  }

  private var activeListings: [Listing] {
    listings.filter { $0.status != .deleted }
  }

  private var navigationList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // Navigation Items
        let items: [SearchResult] = [
          .navigation(title: "Inbox", icon: "tray", tab: .workspace, badgeCount: inboxCount),
          .navigation(title: "Today", icon: "star.fill", tab: .workspace, badgeCount: todayCount),
          .navigation(title: "Listings", icon: "building.2", tab: .listings, badgeCount: nil),
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
