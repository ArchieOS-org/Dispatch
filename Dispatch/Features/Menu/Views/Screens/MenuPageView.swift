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
      .toolbar(.hidden, for: .navigationBar)
    #endif
  }

  // MARK: Private

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager

  @Query private var allTasksRaw: [TaskItem]
  @Query private var allActivitiesRaw: [Activity]
  @Query private var allPropertiesRaw: [Property]
  @Query private var allListingsRaw: [Listing]
  @Query private var allRealtors: [User]

  private var workspaceTasks: [TaskItem] {
    guard let currentUserID = syncManager.currentUserID else { return [] }
    return allTasksRaw.filter { $0.assigneeUserIds.contains(currentUserID) && $0.status != .deleted }
  }

  private var workspaceActivities: [Activity] {
    guard let currentUserID = syncManager.currentUserID else { return [] }
    return allActivitiesRaw.filter { $0.assigneeUserIds.contains(currentUserID) && $0.status != .deleted }
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
    let overdueTasks = workspaceTasks.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
    let overdueActivities = workspaceActivities.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
    return overdueTasks.count + overdueActivities.count
  }

  /// Stage card tap - uses phonePath via dispatch for iPhone navigation.
  private func handleStageCardTap(_ stage: ListingStage) {
    appState.dispatch(.phoneNavigateTo(.stagedListings(stage)))
  }

  private func count(for tab: AppTab) -> Int {
    switch tab {
    case .workspace: workspaceTasks.count + workspaceActivities.count
    case .properties: activeProperties.count
    case .listings: activeListings.count
    case .realtors: activeRealtors.count
    case .settings, .search, .descriptionGenerator: 0
    }
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
    case .descriptionGenerator: .descriptionGenerator(listingId: nil)
    }
  }

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
    MenuPageView()
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
    MenuPageView()
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
    MenuPageView()
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
    MenuPageView()
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
    MenuPageView()
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
      MenuPageView()
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
      MenuPageView()
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
      MenuPageView()
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
