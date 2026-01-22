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
  @Environment(\.undoManager) private var undoManager

  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  /// Use size class for layout decisions - compact means phone-like layout (narrow space).
  /// This includes iPhone portrait AND iPad in narrow Split View column.
  private var isCompactLayout: Bool { horizontalSizeClass == .compact }
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

  private var phonePathBinding: Binding<[AppRoute]> {
    Binding(
      get: { appState.router.phonePath },
      set: { newValue in
        // Defer state change to avoid "Publishing changes from within view updates" warning.
        // Task schedules the dispatch for the next run loop iteration.
        Task { @MainActor in
          appState.dispatch(.setPhonePath(newValue))
        }
      }
    )
  }

  private var currentPathDepth: Int {
    #if os(iOS)
    isCompactLayout ? appState.router.phonePath.count : (appState.router.paths[appState.router.selectedDestination]?.count ?? 0)
    #else
    appState.router.paths[appState.router.selectedDestination]?.count ?? 0
    #endif
  }

  private var bodyCore: some View {
    ZStack {
      navigationContent
      // Status indicators in bottom-left corner
      VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        if appState.syncCoordinator.showRealtimeDegraded {
          RealtimeDegradedIndicator()
        }
        if appState.syncCoordinator.isOffline {
          OfflineIndicator()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      .padding()
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
    .animation(.easeInOut(duration: 0.3), value: appState.syncCoordinator.showRealtimeDegraded)
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
    if isCompactLayout {
      iPhoneContentView(
        phonePathBinding: phonePathBinding, quickFindText: $quickFindText,
        stageCounts: stageCounts, phoneTabCounts: phoneTabCounts, overdueCount: sidebarOverdueCount,
        activeTasks: activeTasks, activeActivities: activeActivities, activeListings: activeListings,
        users: users, currentUserId: currentUserId,
        onSelectSearchResult: selectSearchResult(_:), onRequestSync: { syncManager.requestSync() }
      )
    } else {
      iPadContentView(
        stageCounts: stageCounts,
        workspaceTasks: workspaceTasks, workspaceActivities: workspaceActivities,
        activeListings: activeListings, activeProperties: activeProperties, activeRealtors: activeRealtors,
        pathBindingProvider: pathBinding(for:),
        quickFindText: $quickFindText,
        activeTasks: activeTasks, activeActivities: activeActivities,
        onSelectSearchResult: selectSearchResult(_:)
      )
    }
    #endif
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

  private func pathBinding(for destination: SidebarDestination) -> Binding<[AppRoute]> {
    Binding(
      get: { appState.router.paths[destination] ?? [] },
      set: { newValue in
        // Defer state change to avoid "Publishing changes from within view updates" warning.
        // Task schedules the dispatch for the next run loop iteration.
        Task { @MainActor in
          appState.dispatch(.setPath(newValue, for: destination))
        }
      }
    )
  }

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
      if isCompactLayout {
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
    }
  }
  #endif

  private func updateWorkItemActions() {
    workItemActions.currentUserId = currentUserId
    workItemActions.userLookup = { [userCache] id in userCache[id] }
    workItemActions.userLookupDict = userCache
    workItemActions.availableUsers = users
    workItemActions.undoManager = undoManager
    workItemActions.onComplete = makeOnComplete()
    workItemActions.onAssigneesChanged = makeOnAssigneesChanged()
    workItemActions.onAddNote = makeOnAddNote()
    workItemActions.onDeleteNote = makeOnDeleteNote()
    workItemActions.onClaim = makeOnClaim()
  }

  private func makeOnComplete() -> (WorkItem) -> Void {
    { [syncManager, undoManager] item in
      // Capture previous state before mutation
      let previousStatus: (isCompleted: Bool, completedAt: Date?)
      let actionName: String

      switch item {
      case .task(let t, _):
        previousStatus = (t.status == .completed, t.completedAt)
        t.status = t.status == .completed ? .open : .completed
        t.completedAt = t.status == .completed ? Date() : nil
        t.markPending()
        actionName = t.status == .completed ? "Complete Task" : "Uncomplete Task"

        // Register undo action
        undoManager?.registerUndo(withTarget: t) { task in
          task.status = previousStatus.isCompleted ? .completed : .open
          task.completedAt = previousStatus.completedAt
          task.markPending()
          syncManager.requestSync()
        }

      case .activity(let a, _):
        previousStatus = (a.status == .completed, a.completedAt)
        a.status = a.status == .completed ? .open : .completed
        a.completedAt = a.status == .completed ? Date() : nil
        a.markPending()
        actionName = a.status == .completed ? "Complete Activity" : "Uncomplete Activity"

        // Register undo action
        undoManager?.registerUndo(withTarget: a) { activity in
          activity.status = previousStatus.isCompleted ? .completed : .open
          activity.completedAt = previousStatus.completedAt
          activity.markPending()
          syncManager.requestSync()
        }
      }
      undoManager?.setActionName(actionName)
      syncManager.requestSync()
    }
  }

  private func makeOnAssigneesChanged() -> (WorkItem, [UUID]) -> Void {
    { [syncManager, currentUserId, undoManager] item, userIds in
      // Capture previous assignee IDs before mutation
      let previousAssigneeIds: [UUID]
      let set = Set(userIds)

      switch item {
      case .task(let t, _):
        previousAssigneeIds = t.assigneeUserIds
        t.assignees.removeAll { !set.contains($0.userId) }
        let existing = Set(t.assignees.map { $0.userId })
        for uid in userIds where !existing.contains(uid) {
          let a = TaskAssignee(
            taskId: t.id,
            userId: uid,
            assignedBy: currentUserId
          )
          a.task = t
          t.assignees.append(a)
        }
        t.markPending()

        // Register undo action to restore previous assignees
        undoManager?.registerUndo(withTarget: t) { [previousAssigneeIds, currentUserId] task in
          let restoreSet = Set(previousAssigneeIds)
          task.assignees.removeAll { !restoreSet.contains($0.userId) }
          let existingIds = Set(task.assignees.map { $0.userId })
          for uid in previousAssigneeIds where !existingIds.contains(uid) {
            let assignee = TaskAssignee(
              taskId: task.id,
              userId: uid,
              assignedBy: currentUserId
            )
            assignee.task = task
            task.assignees.append(assignee)
          }
          task.markPending()
          syncManager.requestSync()
        }

      case .activity(let a, _):
        previousAssigneeIds = a.assigneeUserIds
        a.assignees.removeAll { !set.contains($0.userId) }
        let existing = Set(a.assignees.map { $0.userId })
        for uid in userIds where !existing.contains(uid) {
          let x = ActivityAssignee(
            activityId: a.id,
            userId: uid,
            assignedBy: currentUserId
          )
          x.activity = a
          a.assignees.append(x)
        }
        a.markPending()

        // Register undo action to restore previous assignees
        undoManager?.registerUndo(withTarget: a) { [previousAssigneeIds, currentUserId] activity in
          let restoreSet = Set(previousAssigneeIds)
          activity.assignees.removeAll { !restoreSet.contains($0.userId) }
          let existingIds = Set(activity.assignees.map { $0.userId })
          for uid in previousAssigneeIds where !existingIds.contains(uid) {
            let assignee = ActivityAssignee(
              activityId: activity.id,
              userId: uid,
              assignedBy: currentUserId
            )
            assignee.activity = activity
            activity.assignees.append(assignee)
          }
          activity.markPending()
          syncManager.requestSync()
        }
      }
      undoManager?.setActionName("Change Assignees")
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

  private func makeOnClaim() -> (WorkItem) -> Void {
    { [syncManager, currentUserId, workItemActions] item in
      guard syncManager.currentUserID != nil else { return }
      var newAssignees = item.assigneeUserIds
      if !newAssignees.contains(currentUserId) {
        newAssignees.append(currentUserId)
      }
      workItemActions.onAssigneesChanged(item, newAssignees)
    }
  }

  private func makeOnDeleteNote() -> (Note, WorkItem) -> Void {
    { [syncManager, currentUserId, undoManager] note, _ in
      // Perform soft delete
      note.softDelete(by: currentUserId)
      syncManager.requestSync()

      // Register undo action
      undoManager?.registerUndo(withTarget: note) { note in
        note.undoDelete()
        syncManager.requestSync()
      }
      undoManager?.setActionName("Delete Note")
    }
  }

  private func updateLensState() {
    let dest = appState.router.selectedDestination, depth = currentPathDepth
    #if os(iOS)
    if isCompactLayout, depth == 0 { if appState.lensState.currentScreen != .menu { appState.lensState.currentScreen = .menu }
      return
    }
    #endif
    let screen: LensState.CurrentScreen =
      switch dest {
      case .tab(let tab): switch tab {
        case .workspace: .myWorkspace
        case .properties, .settings, .search: .other
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
  #if os(macOS)
    .environment(WindowUIState())
  #endif
}
