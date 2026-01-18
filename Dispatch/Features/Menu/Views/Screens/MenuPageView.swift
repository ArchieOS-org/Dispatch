//
//  MenuPageView.swift
//  Dispatch
//
//  Things 3-style menu page for iPhone navigation.
//

import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - MenuPageView

struct MenuPageView: View {

  // MARK: Lifecycle

  init(
    stageCounts: [ListingStage: Int],
    tabCounts: [AppTab: Int],
    overdueCount: Int
  ) {
    self.stageCounts = stageCounts
    self.tabCounts = tabCounts
    self.overdueCount = overdueCount
  }

  // MARK: Internal

  var body: some View {
    List {
      // MARK: - Stage Cards Section
      Section {
        StageCardsSection(
          stageCounts: stageCounts,
          onSelectStage: handleStageCardTap
        )
      }
      .listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))
      .listRowBackground(DS.Colors.Background.primary)
      .listRowSeparator(.hidden)

      // MARK: - Menu Sections (Push Navigation via phonePath)
      ForEach(AppTab.menuTabs) { tab in
        Button {
          appState.dispatch(.phoneNavigateTo(route(for: tab)))
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
    .pullToSearchTracking()
    #if os(iOS)
      // Add bottom margin to clear floating buttons on iPhone
      .contentMargins(.bottom, DS.Spacing.floatingButtonScrollInset, for: .scrollContent)
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  // MARK: Private

  /// Stage counts passed from parent (ContentView owns the @Query)
  private let stageCounts: [ListingStage: Int]

  /// Tab item counts passed from parent (ContentView owns the @Query)
  private let tabCounts: [AppTab: Int]

  /// Overdue work item count passed from parent
  private let overdueCount: Int

  @EnvironmentObject private var appState: AppState

  /// Stage card tap - uses phonePath via dispatch for iPhone navigation.
  private func handleStageCardTap(_ stage: ListingStage) {
    appState.dispatch(.phoneNavigateTo(.stagedListings(stage)))
  }

  private func count(for tab: AppTab) -> Int {
    tabCounts[tab] ?? 0
  }

  /// Maps menu tabs to navigation routes for push navigation
  private func route(for tab: AppTab) -> AppRoute {
    switch tab {
    case .workspace: .workspace
    case .properties: .propertiesList
    case .listings: .listingsList
    case .realtors: .realtorsList
    case .settings: .settingsRoot
    case .search: .workspace // Search is overlay, shouldn't be pushed
    }
  }

}

// MARK: - MenuPagePreviewData

private enum MenuPagePreviewData {
  static let stageCounts: [ListingStage: Int] = [
    .pending: 2,
    .workingOn: 1,
    .live: 3,
    .sold: 1,
    .done: 5
  ]

  static let tabCounts: [AppTab: Int] = [
    .workspace: 8,
    .properties: 6,
    .listings: 4,
    .realtors: 3
  ]

  static let emptyTabCounts: [AppTab: Int] = [
    .workspace: 0,
    .properties: 0,
    .listings: 1,
    .realtors: 0
  ]

  static let richTabCounts: [AppTab: Int] = [
    .workspace: 12,
    .properties: 8,
    .listings: 4,
    .realtors: 6
  ]
}

// MARK: - Previews

#Preview("Menu - Pull to Search") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)
    }
  ) { _ in
    MenuPageView(
      stageCounts: MenuPagePreviewData.stageCounts,
      tabCounts: MenuPagePreviewData.tabCounts,
      overdueCount: 0
    )
  }
}

#Preview("Menu - With Claimed Items") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)

      // Add more items claimed by Bob for variety
      let listing = try? context.fetch(FetchDescriptor<Listing>()).first

      // Additional assigned task
      let task = TaskItem(
        title: "Schedule Appraisal",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      task.syncState = .synced
      listing?.tasks.append(task)

      // Assigned activity
      let activity = Activity(
        title: "Follow Up Call",
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      activity.syncState = .synced
      listing?.activities.append(activity)
    }
  ) { _ in
    MenuPageView(
      stageCounts: MenuPagePreviewData.stageCounts,
      tabCounts: MenuPagePreviewData.tabCounts,
      overdueCount: 0
    )
  }
}

#Preview("Menu - Empty Workspace") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      // Seed users but no items claimed by Bob
      let alice = User(
        id: PreviewDataFactory.aliceID,
        name: "Alice Owner",
        email: "alice@dispatch.com",
        userType: .admin
      )
      alice.syncState = .synced
      context.insert(alice)

      let bob = User(
        id: PreviewDataFactory.bobID,
        name: "Bob Agent",
        email: "bob@dispatch.com",
        userType: .realtor
      )
      bob.syncState = .synced
      context.insert(bob)

      // Add listing with unclaimed tasks
      let listing = Listing(
        id: PreviewDataFactory.listingID,
        address: "456 Empty Lane",
        status: .active,
        ownedBy: PreviewDataFactory.aliceID
      )
      listing.syncState = .synced
      context.insert(listing)

      let unclaimedTask = TaskItem(
        title: "Unclaimed Task",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing.id
      )
      unclaimedTask.syncState = .synced
      listing.tasks.append(unclaimedTask)
    }
  ) { _ in
    MenuPageView(
      stageCounts: [:],
      tabCounts: MenuPagePreviewData.emptyTabCounts,
      overdueCount: 0
    )
  }
}

#Preview("Menu - With Overdue Items") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)

      let listing = try? context.fetch(FetchDescriptor<Listing>()).first

      // Overdue task (due yesterday)
      let overdueTask = TaskItem(
        title: "Urgent: Fix Plumbing",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      overdueTask.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
      overdueTask.syncState = .synced
      listing?.tasks.append(overdueTask)

      // Another overdue task
      let overdueTask2 = TaskItem(
        title: "Overdue: Submit Documents",
        status: .inProgress,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      overdueTask2.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
      overdueTask2.syncState = .synced
      listing?.tasks.append(overdueTask2)

      // Overdue activity
      let overdueActivity = Activity(
        title: "Missed: Client Meeting",
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      overdueActivity.dueDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
      overdueActivity.syncState = .synced
      listing?.activities.append(overdueActivity)
    }
  ) { _ in
    MenuPageView(
      stageCounts: MenuPagePreviewData.stageCounts,
      tabCounts: MenuPagePreviewData.tabCounts,
      overdueCount: 3
    )
  }
}

#Preview("Menu - Rich Data") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      // Users
      let alice = User(
        id: PreviewDataFactory.aliceID,
        name: "Alice Owner",
        email: "alice@dispatch.com",
        userType: .admin
      )
      alice.syncState = .synced
      context.insert(alice)

      let bob = User(
        id: PreviewDataFactory.bobID,
        name: "Bob Agent",
        email: "bob@dispatch.com",
        userType: .realtor
      )
      bob.syncState = .synced
      context.insert(bob)

      // Multiple realtors
      for i in 1 ... 5 {
        let realtor = User(
          id: UUID(),
          name: "Realtor \(i)",
          email: "realtor\(i)@dispatch.com",
          userType: .realtor
        )
        realtor.syncState = .synced
        context.insert(realtor)
      }

      // Multiple properties
      for i in 1 ... 8 {
        let property = Property(
          id: UUID(),
          address: "\(100 + i) Property St",
          ownedBy: PreviewDataFactory.aliceID
        )
        property.syncState = .synced
        context.insert(property)
      }

      // Multiple listings with tasks claimed by Bob
      for i in 1 ... 4 {
        let listing = Listing(
          id: UUID(),
          address: "\(200 + i) Listing Ave",
          status: .active,
          ownedBy: PreviewDataFactory.aliceID
        )
        listing.syncState = .synced
        context.insert(listing)

        // Add assigned tasks to each listing
        for j in 1 ... 2 {
          let task = TaskItem(
            title: "Task \(j) for Listing \(i)",
            status: .open,
            declaredBy: PreviewDataFactory.aliceID,
            listingId: listing.id,
            assigneeUserIds: [PreviewDataFactory.bobID]
          )
          task.syncState = .synced
          listing.tasks.append(task)
        }

        // Add assigned activity
        let activity = Activity(
          title: "Activity for Listing \(i)",
          declaredBy: PreviewDataFactory.aliceID,
          listingId: listing.id,
          assigneeUserIds: [PreviewDataFactory.bobID]
        )
        activity.syncState = .synced
        listing.activities.append(activity)
      }
    }
  ) { _ in
    MenuPageView(
      stageCounts: MenuPagePreviewData.stageCounts,
      tabCounts: MenuPagePreviewData.richTabCounts,
      overdueCount: 0
    )
  }
}

// MARK: - Container Context Previews (iOS only - uses UIColor)

#if os(iOS)

#Preview("Menu - In NavigationSplitView Sidebar") {
  PreviewShell(
    withNavigation: false,
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)

      let listing = try? context.fetch(FetchDescriptor<Listing>()).first

      // Add assigned items for Bob
      let task = TaskItem(
        title: "Schedule Appraisal",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      task.syncState = .synced
      listing?.tasks.append(task)
    }
  ) { _ in
    NavigationSplitView {
      MenuPageView(
        stageCounts: MenuPagePreviewData.stageCounts,
        tabCounts: MenuPagePreviewData.tabCounts,
        overdueCount: 0
      )
      .navigationTitle("Dispatch")
    } detail: {
      Text("Detail View")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .navigationSplitViewStyle(.balanced)
  }
}

#Preview("Menu - iPad Landscape", traits: .landscapeLeft) {
  PreviewShell(
    withNavigation: false,
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)

      let listing = try? context.fetch(FetchDescriptor<Listing>()).first

      // Multiple assigned items
      for i in 1 ... 5 {
        let task = TaskItem(
          title: "Task \(i)",
          status: .open,
          declaredBy: PreviewDataFactory.aliceID,
          listingId: listing?.id,
          assigneeUserIds: [PreviewDataFactory.bobID]
        )
        task.syncState = .synced
        listing?.tasks.append(task)
      }
    }
  ) { _ in
    NavigationSplitView {
      MenuPageView(
        stageCounts: MenuPagePreviewData.stageCounts,
        tabCounts: MenuPagePreviewData.richTabCounts,
        overdueCount: 0
      )
      .navigationTitle("Dispatch")
    } detail: {
      Text("Select an item")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .navigationSplitViewStyle(.balanced)
  }
}

#Preview("Menu - Sidebar Width Constrained") {
  PreviewShell(
    withNavigation: false,
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      PreviewDataFactory.seed(context)
    }
  ) { _ in
    HStack(spacing: 0) {
      // Simulated sidebar at typical width
      MenuPageView(
        stageCounts: MenuPagePreviewData.stageCounts,
        tabCounts: MenuPagePreviewData.tabCounts,
        overdueCount: 0
      )
      .frame(width: 320)
      .background(Color(uiColor: .systemGroupedBackground))

      Divider()

      // Detail placeholder
      Text("Detail Content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
  }
}

#endif
