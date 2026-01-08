//
//  MenuPageView.swift
//  Dispatch
//
//  Things 3-style menu page for iPhone navigation.
//

import SwiftData
import SwiftUI

struct MenuPageView: View {

  // MARK: Internal

  var body: some View {
    List {
      // MARK: - Stage Cards Section
      Section {
        StageCardsSection(
          stageCounts: stageCounts,
          onSelectStage: { stage in
            appState.router.path.append(.stagedListings(stage))
          },
        )
      }
      .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))
      .listRowBackground(DS.Colors.Background.primary)
      .listRowSeparator(.hidden)

      // MARK: - Menu Sections (Tab Switches)
      ForEach(AppTab.menuTabs) { tab in
        Button {
          appState.dispatch(.selectTab(tab))
        } label: {
          SidebarMenuRow(
            tab: tab,
            itemCount: count(for: tab),
            overdueCount: tab == .workspace ? overdueCount : 0
          )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))
        .listRowBackground(DS.Colors.Background.primary)
        .listRowSeparator(.hidden)
        .padding(.top, tab == .settings ? DS.Spacing.xl : 0)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(DS.Colors.Background.primary)
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .top) {
        Color.clear.frame(height: DS.Spacing.sm)
      }
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState

  @Query private var allTasksRaw: [TaskItem]
  @Query private var allActivitiesRaw: [Activity]
  @Query private var allPropertiesRaw: [Property]
  @Query private var allListingsRaw: [Listing]
  @Query private var allRealtors: [User]

  private var openTasks: [TaskItem] {
    allTasksRaw.filter { $0.status != .completed && $0.status != .deleted }
  }

  private var openActivities: [Activity] {
    allActivitiesRaw.filter { $0.status != .completed && $0.status != .deleted }
  }

  private var activeProperties: [Property] {
    allPropertiesRaw.filter { $0.deletedAt == nil }
  }

  private var activeListings: [Listing] {
    allListingsRaw.filter { $0.status != .deleted }
  }

  private var activeRealtors: [User] {
    allRealtors.filter { $0.userType == .realtor }
  }

  /// Stage counts computed once per render cycle from activeListings.
  private var stageCounts: [ListingStage: Int] {
    activeListings.stageCounts()
  }

  private var overdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    let overdueTasks = openTasks.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
    let overdueActivities = openActivities.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
    return overdueTasks.count + overdueActivities.count
  }

  private func count(for tab: AppTab) -> Int {
    switch tab {
    case .workspace: openTasks.count + openActivities.count
    case .properties: activeProperties.count
    case .listings: activeListings.count
    case .realtors: activeRealtors.count
    case .settings, .search: 0
    }
  }

}

// MARK: - Previews

#Preview("Menu Page View") {
  NavigationStack {
    MenuPageView()
  }
  .modelContainer(for: [TaskItem.self, Activity.self, Property.self, Listing.self, User.self], inMemory: true)
  .environmentObject(AppState())
  .environmentObject(SyncManager(mode: .preview))
  .environmentObject(LensState())
}
