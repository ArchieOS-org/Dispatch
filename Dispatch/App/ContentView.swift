//  ContentView.swift - Root navigation coordinator
//  Created by Noah Deskin on 2025-12-06.

import SwiftData
import SwiftUI

/// Root view coordinator: owns @Query data, delegates to platform views
struct ContentView: View {

  // MARK: Internal

  var body: some View {
    bodyCore
      .environmentObject(workItemActions)
      .environmentObject(appState.lensState)
      .environmentObject(overlayState)
  }

  // MARK: Private

  // swiftlint:disable:next force_unwrapping
  private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var appState: AppState
  @Environment(\.modelContext) private var modelContext

  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
  #endif

  @Query private var users: [User]
  @Query private var allListings: [Listing]
  @Query private var allTasksRaw: [TaskItem]
  @Query private var allActivitiesRaw: [Activity]
  @Query private var allPropertiesRaw: [Property]
  @Query private var allRealtorsRaw: [User]

  @StateObject private var workItemActions = WorkItemActions()
  @StateObject private var overlayState = AppOverlayState()

  #if os(iOS)
  @State private var quickFindText = ""
  #endif

  private var userCache: [UUID: User] { Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) }) }
  private var currentUserId: UUID { syncManager.currentUserID ?? Self.unauthenticatedUserId }

  private var workspaceTasks: [TaskItem] {
    guard let uid = syncManager.currentUserID else { return [] }
    return allTasksRaw.filter { $0.assigneeUserIds.contains(uid) && $0.status != .deleted }
  }

  private var workspaceActivities: [Activity] {
    guard let uid = syncManager.currentUserID else { return [] }
    return allActivitiesRaw.filter { $0.assigneeUserIds.contains(uid) && $0.status != .deleted }
  }

  private var activeProperties: [Property] { allPropertiesRaw.filter { $0.deletedAt == nil } }
  private var activeListings: [Listing] { allListings.filter { $0.status != .deleted } }
  private var activeTasks: [TaskItem] { allTasksRaw.filter { $0.status != .deleted } }
  private var activeActivities: [Activity] { allActivitiesRaw.filter { $0.status != .deleted } }
  private var activeRealtors: [User] { allRealtorsRaw.filter { $0.userType == .realtor } }
  private var stageCounts: [ListingStage: Int] { activeListings.stageCounts() }

  private var selectedDestinationBinding: Binding<SidebarDestination> {
    Binding(
      get: { appState.router.selectedDestination },
      set: { appState.dispatch(.userSelectedDestination($0)) }
    )
  }

  private var phonePathBinding: Binding<[AppRoute]> {
    Binding(
      get: { appState.router.phonePath },
      set: { appState.dispatch(.setPhonePath($0)) }
    )
  }

  private var currentPathDepth: Int {
    #if os(iOS)
    isPhone ? appState.router.phonePath.count : (appState.router.paths[appState.router.selectedDestination]?.count ?? 0)
    #else
    appState.router.paths[appState.router.selectedDestination]?.count ?? 0
    #endif
  }

  private var bodyCore: some View {
    ZStack {
      navigationContent
      if appState.syncCoordinator.isOffline {
        OfflineIndicator()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
          .padding()
      }
      #if DEBUG
      if ProcessInfo.processInfo.environment["DISPATCH_PROBE"] == "1" {
        Button { appState.dispatch(.openSearch(initialText: "probe")) } label: {
          Text("Architectural Probe").padding().background(Color.red).foregroundColor(.white)
            .cornerRadius(DS.Spacing.radiusMedium)
        }
        .accessibilityIdentifier("DispatchProbe").zIndex(999)
      }
      #endif
    }
    .animation(.easeInOut(duration: 0.3), value: appState.syncCoordinator.isOffline)
    .onAppear { updateWorkItemActions()
      updateLensState()
    }
    .onChange(of: currentUserId) { _, _ in updateWorkItemActions() }
    .onChange(of: userCache) { _, _ in updateWorkItemActions() }
    .onChange(of: appState.router.selectedDestination) { _, _ in updateLensState() }
    .onChange(of: currentPathDepth) { _, _ in updateLensState() }
  }

  @ViewBuilder
  private var navigationContent: some View {
    #if os(macOS)
    MacContentView(
      stageCounts: stageCounts, workspaceTasks: workspaceTasks, workspaceActivities: workspaceActivities,
      activeListings: activeListings, activeProperties: activeProperties, activeRealtors: activeRealtors,
      users: users, currentUserId: currentUserId, pathBindingProvider: pathBinding(for:),
      onSelectSearchResult: selectSearchResult(_:), onRequestSync: { syncManager.requestSync() }
    )
    #else
    if isPhone {
      iPhoneContentView(
        phonePathBinding: phonePathBinding, quickFindText: $quickFindText,
        stageCounts: stageCounts, phoneTabCounts: phoneTabCounts, overdueCount: sidebarOverdueCount,
        activeTasks: activeTasks, activeActivities: activeActivities, activeListings: activeListings,
        users: users, currentUserId: currentUserId,
        onSelectSearchResult: selectSearchResult(_:), onRequestSync: { syncManager.requestSync() }
      )
    } else {
      iPadContentView(
        selectedDestinationBinding: selectedDestinationBinding, stageCounts: stageCounts,
        workspaceTasks: workspaceTasks, workspaceActivities: workspaceActivities,
        activeListings: activeListings, activeProperties: activeProperties, activeRealtors: activeRealtors,
        pathBindingProvider: pathBinding(for:)
      )
    }
    #endif
  }

  private func pathBinding(for destination: SidebarDestination) -> Binding<[AppRoute]> {
    Binding(
      get: { appState.router.paths[destination] ?? [] },
      set: { appState.dispatch(.setPath($0, for: destination)) }
    )
  }

  #if os(iOS)
  /// Overdue count for MenuPageView badge.
  private var sidebarOverdueCount: Int {
    let startOfToday = Calendar.current.startOfDay(for: Date())
    return workspaceTasks.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
      + workspaceActivities.count(where: { ($0.dueDate ?? .distantFuture) < startOfToday })
  }

  /// Tab counts for MenuPageView (iPhone menu).
  private var phoneTabCounts: [AppTab: Int] {
    [
      .workspace: workspaceTasks.count + workspaceActivities.count,
      .properties: activeProperties.count,
      .listings: activeListings.count,
      .realtors: activeRealtors.count
    ]
  }
  #endif

  private func selectSearchResult(_ result: SearchResult) {
    switch result {
    case .task(let task):
      appState.dispatch(.selectTab(.workspace))
      appState.dispatch(.navigate(.workItem(.task(task))))
    case .activity(let activity):
      appState.dispatch(.selectTab(.workspace))
      appState.dispatch(.navigate(.workItem(.activity(activity))))
    case .listing(let listing):
      appState.dispatch(.selectTab(.listings))
      appState.dispatch(.navigate(.listing(listing.id)))
    case .navigation(_, _, let tab, _):
      #if os(iOS)
      if isPhone {
        appState.dispatch(.phonePopToRoot)
        appState.dispatch(.phoneNavigateTo(routeFor(tab: tab)))
      } else { appState.dispatch(.selectTab(tab)) }
      #else
      appState.dispatch(.selectTab(tab))
      #endif
    }
  }

  #if os(iOS)
  private func routeFor(tab: AppTab) -> AppRoute {
    switch tab {
    case .workspace: .workspace
    case .properties: .propertiesList
    case .listings: .listingsList
    case .realtors: .realtorsList
    case .settings: .settingsRoot
    case .search: .workspace
    case .listingGenerator: .listingGenerator(listingId: nil)
    }
  }
  #endif

  private func updateWorkItemActions() {
    workItemActions.currentUserId = currentUserId
    workItemActions.userLookup = { [userCache] id in userCache[id] }
    workItemActions.userLookupDict = userCache
    workItemActions.availableUsers = users
    workItemActions.onComplete = makeOnComplete()
    workItemActions.onAssigneesChanged = makeOnAssigneesChanged()
    workItemActions.onAddNote = makeOnAddNote()
    workItemActions.onDeleteNote = { [syncManager, currentUserId] note, _ in note.softDelete(by: currentUserId)
      syncManager.requestSync()
    }
  }

  private func makeOnComplete() -> (WorkItem) -> Void {
    { [syncManager] item in
      switch item {
      case .task(let t, _): t.status = t.status == .completed ? .open : .completed
        t.completedAt = t.status == .completed ? Date() : nil
        t.markPending()

      case .activity(let a, _): a.status = a.status == .completed ? .open : .completed
        a.completedAt = a.status == .completed ? Date() : nil
        a.markPending()
      }
      syncManager.requestSync()
    }
  }

  private func makeOnAssigneesChanged() -> (WorkItem, [UUID]) -> Void {
    { [syncManager, currentUserId] item, userIds in
      let set = Set(userIds)
      switch item {
      case .task(let t, _):
        t.assignees.removeAll { !set.contains($0.userId) }
        let existing = Set(t.assignees.map { $0.userId })
        for uid in userIds where !existing.contains(uid) { let a = TaskAssignee(
          taskId: t.id,
          userId: uid,
          assignedBy: currentUserId
        )
        a.task = t
        t.assignees.append(a)
        }
        t.markPending()

      case .activity(let a, _):
        a.assignees.removeAll { !set.contains($0.userId) }
        let existing = Set(a.assignees.map { $0.userId })
        for uid in userIds where !existing.contains(uid) { let x = ActivityAssignee(
          activityId: a.id,
          userId: uid,
          assignedBy: currentUserId
        )
        x.activity = a
        a.assignees.append(x)
        }
        a.markPending()
      }
      syncManager.requestSync()
    }
  }

  private func makeOnAddNote() -> (String, WorkItem) -> Void {
    { [syncManager, currentUserId] content, item in
      switch item {
      case .task(let t, _): let n = Note(content: content, createdBy: currentUserId, parentType: .task, parentId: t.id)
        t.notes.append(n)
        t.markPending()

      case .activity(let a, _): let n = Note(content: content, createdBy: currentUserId, parentType: .activity, parentId: a.id)
        a.notes.append(n)
        a.markPending()
      }
      syncManager.requestSync()
    }
  }

  private func updateLensState() {
    let dest = appState.router.selectedDestination, depth = currentPathDepth
    #if os(iOS)
    if isPhone, depth == 0 { if appState.lensState.currentScreen != .menu { appState.lensState.currentScreen = .menu }
      return
    }
    #endif
    let screen: LensState.CurrentScreen =
      switch dest {
      case .tab(let tab): switch tab {
        case .workspace: .myWorkspace
        case .properties, .settings, .search, .listingGenerator: .other
        case .listings: depth > 0 ? .listingDetail : .listings
        case .realtors: .realtors
        }

      case .stage: depth > 0 ? .listingDetail : .listings
      }
    if appState.lensState.currentScreen != screen { appState.lensState.currentScreen = screen }
  }
}

#Preview {
  ContentView()
    .modelContainer(for: [TaskItem.self, Activity.self, Listing.self, User.self], inMemory: true)
    .environmentObject(SyncManager.shared)
    .environmentObject(AppState(mode: .preview))
}
