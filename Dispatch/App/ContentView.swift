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
  @StateObject private var searchEnvironment = SearchEnvironment()

  #if os(iOS)
  @State private var quickFindText = ""
  #endif

  /// ViewModel for instant search - created immediately from searchEnvironment.
  /// Non-optional to ensure all views share the same warmed SearchIndexService.
  /// The VM is created eagerly but the index is warmed asynchronously via .task.
  @State private var searchViewModel: SearchViewModel?
  /// Flag to track if warm start has been triggered
  @State private var hasStartedWarmStart = false

  /// Pre-built task dictionary for O(1) lookup by ID.
  /// Rebuilt when activeTasks changes.
  private var taskLookup: [UUID: TaskItem] {
    Dictionary(uniqueKeysWithValues: activeTasks.map { ($0.id, $0) })
  }

  /// Safe accessor for searchViewModel that creates one from shared environment if needed.
  /// This ensures the ViewModel always shares the same SearchIndexService.
  private var safeSearchViewModel: SearchViewModel {
    searchViewModel ?? searchEnvironment.makeViewModel()
  }

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
    .onAppear {
      // Wire UndoManager to ModelContext for SwiftData undo/redo support
      modelContext.undoManager = undoManager
      updateWorkItemActions()
      updateLensState()
      // Create searchViewModel eagerly using shared environment.
      // This ensures all child views share the same warmed SearchIndexService.
      if searchViewModel == nil {
        searchViewModel = searchEnvironment.makeViewModel()
      }
    }
    .onChange(of: currentUserId) { _, _ in updateWorkItemActions() }
    .onChange(of: userCache) { _, _ in updateWorkItemActions() }
    .onChange(of: appState.router.selectedDestination) { _, _ in updateLensState() }
    .onChange(of: currentPathDepth) { _, _ in updateLensState() }
    // Warm start search index after first frame renders (deferred via .task)
    .task {
      guard !hasStartedWarmStart else { return }
      hasStartedWarmStart = true
      await warmStartSearchIndex()
    }
  }

  @ViewBuilder
  private var navigationContent: some View {
    #if os(macOS)
    MacContentView(
      stageCounts: stageCounts, workspaceTasks: workspaceTasks, workspaceActivities: workspaceActivities,
      activeListings: activeListings, activeProperties: activeProperties, activeRealtors: activeRealtors,
      users: users, currentUserId: currentUserId, pathBindingProvider: pathBinding(for:),
      searchViewModel: safeSearchViewModel,
      onSelectSearchResult: selectSearchResult(_:), onRequestSync: { syncManager.requestSync() }
    )
    #else
    if isCompactLayout {
      iPhoneContentView(
        phonePathBinding: phonePathBinding, quickFindText: $quickFindText,
        stageCounts: stageCounts, phoneTabCounts: phoneTabCounts, overdueCount: sidebarOverdueCount,
        activeListings: activeListings,
        users: users, currentUserId: currentUserId,
        searchViewModel: safeSearchViewModel,
        onSelectSearchResult: selectSearchResult(_:), onRequestSync: { syncManager.requestSync() }
      )
    } else {
      iPadContentView(
        stageCounts: stageCounts,
        workspaceTasks: workspaceTasks, workspaceActivities: workspaceActivities,
        activeListings: activeListings, activeProperties: activeProperties, activeRealtors: activeRealtors,
        pathBindingProvider: pathBinding(for:),
        quickFindText: $quickFindText,
        searchViewModel: safeSearchViewModel,
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

  /// Builds InitialSearchData and warms up the search index.
  /// Called via .task {} to ensure it runs after the first frame renders.
  /// Extracts Sendable DTOs from @Model types ON MainActor before crossing to background actor.
  @MainActor
  private func warmStartSearchIndex() async {
    // Create SearchViewModel from environment
    let viewModel = searchEnvironment.makeViewModel()
    searchViewModel = viewModel

    // Extract Sendable DTOs from @Model types ON MainActor
    // This is required because @Model types are MainActor-isolated and cannot cross actor boundaries
    let searchableRealtors = activeRealtors.map { user in
      SearchableRealtor(
        id: user.id,
        name: user.name,
        email: user.email,
        updatedAt: user.updatedAt
      )
    }

    let searchableListings = activeListings.map { listing in
      SearchableListing(
        id: listing.id,
        address: listing.address,
        city: listing.city,
        postalCode: listing.postalCode,
        statusRawValue: listing.status.rawValue,
        statusDisplayName: listing.status.displayName,
        updatedAt: listing.updatedAt
      )
    }

    let searchableProperties = activeProperties.map { property in
      SearchableProperty(
        id: property.id,
        displayAddress: property.displayAddress,
        city: property.city,
        postalCode: property.postalCode,
        propertyTypeDisplayName: property.propertyType.displayName,
        updatedAt: property.updatedAt
      )
    }

    let searchableTasks = activeTasks.map { task in
      SearchableTask(
        id: task.id,
        title: task.title,
        taskDescription: task.taskDescription,
        statusRawValue: task.status.rawValue,
        statusDisplayName: task.status.displayName,
        updatedAt: task.updatedAt
      )
    }

    // Build initial data bundle with Sendable DTOs - NO Activities per contract
    let data = InitialSearchData(
      realtors: searchableRealtors,
      listings: searchableListings,
      properties: searchableProperties,
      tasks: searchableTasks
    )

    // Warm start in background with utility priority
    await Task(priority: .utility) {
      await viewModel.warmStart(with: data)
    }.value
  }

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

    case .searchDoc(let doc):
      // Navigate based on SearchDoc type
      navigateToSearchDoc(doc)
    }
  }

  /// Navigates to the appropriate detail view for a SearchDoc result.
  /// SearchDoc contains the entity ID and type, which we use to navigate.
  private func navigateToSearchDoc(_ doc: SearchDoc) {
    switch doc.type {
    case .realtor:
      appState.dispatch(.selectTab(.realtors))
      appState.dispatch(.navigate(.realtor(doc.id)))

    case .listing:
      appState.dispatch(.selectTab(.listings))
      appState.dispatch(.navigate(.listing(doc.id)))

    case .property:
      appState.dispatch(.selectTab(.properties))
      appState.dispatch(.navigate(.property(doc.id)))

    case .task:
      // For tasks, we need to find the actual TaskItem to navigate
      // Navigate to workspace and use the task ID
      // Uses O(1) dictionary lookup instead of O(n) linear search
      appState.dispatch(.selectTab(.workspace))
      if let task = taskLookup[doc.id] {
        appState.dispatch(.navigate(.workItem(.task(task))))
      }
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
    workItemActions.onListingStageChanged = makeOnListingStageChanged()
    workItemActions.onAddNoteToListing = makeOnAddNoteToListing()
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
        let newStatus = t.status
        let newCompletedAt = t.completedAt
        actionName = newStatus == .completed ? "Complete Task" : "Uncomplete Task"

        // Register undo action with redo support
        undoManager?.registerUndo(withTarget: t) { [undoManager] task in
          task.status = previousStatus.isCompleted ? .completed : .open
          task.completedAt = previousStatus.completedAt
          task.markPending()

          // Register redo action (reverse of undo)
          undoManager?.registerUndo(withTarget: task) { [undoManager] task in
            task.status = newStatus
            task.completedAt = newCompletedAt
            task.markPending()
            syncManager.requestSync()
            undoManager?.setActionName(actionName)
          }
          undoManager?.setActionName(actionName)
          syncManager.requestSync()
        }

      case .activity(let a, _):
        previousStatus = (a.status == .completed, a.completedAt)
        a.status = a.status == .completed ? .open : .completed
        a.completedAt = a.status == .completed ? Date() : nil
        a.markPending()
        let newStatus = a.status
        let newCompletedAt = a.completedAt
        actionName = newStatus == .completed ? "Complete Activity" : "Uncomplete Activity"

        // Register undo action with redo support
        undoManager?.registerUndo(withTarget: a) { [undoManager] activity in
          activity.status = previousStatus.isCompleted ? .completed : .open
          activity.completedAt = previousStatus.completedAt
          activity.markPending()

          // Register redo action (reverse of undo)
          undoManager?.registerUndo(withTarget: activity) { [undoManager] activity in
            activity.status = newStatus
            activity.completedAt = newCompletedAt
            activity.markPending()
            syncManager.requestSync()
            undoManager?.setActionName(actionName)
          }
          undoManager?.setActionName(actionName)
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
        let newAssigneeIds = userIds

        // Register undo action to restore previous assignees with redo support
        undoManager?.registerUndo(withTarget: t) { [previousAssigneeIds, newAssigneeIds, currentUserId, undoManager] task in
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

          // Register redo action (reverse of undo)
          undoManager?.registerUndo(withTarget: task) { [newAssigneeIds, currentUserId, undoManager] task in
            let redoSet = Set(newAssigneeIds)
            task.assignees.removeAll { !redoSet.contains($0.userId) }
            let existingIds = Set(task.assignees.map { $0.userId })
            for uid in newAssigneeIds where !existingIds.contains(uid) {
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
            undoManager?.setActionName("Change Assignees")
          }
          undoManager?.setActionName("Change Assignees")
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
        let newAssigneeIds = userIds

        // Register undo action to restore previous assignees with redo support
        undoManager?.registerUndo(withTarget: a) { [previousAssigneeIds, newAssigneeIds, currentUserId, undoManager] activity in
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

          // Register redo action (reverse of undo)
          undoManager?.registerUndo(withTarget: activity) { [newAssigneeIds, currentUserId, undoManager] activity in
            let redoSet = Set(newAssigneeIds)
            activity.assignees.removeAll { !redoSet.contains($0.userId) }
            let existingIds = Set(activity.assignees.map { $0.userId })
            for uid in newAssigneeIds where !existingIds.contains(uid) {
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
            undoManager?.setActionName("Change Assignees")
          }
          undoManager?.setActionName("Change Assignees")
          syncManager.requestSync()
        }
      }
      undoManager?.setActionName("Change Assignees")
      syncManager.requestSync()
    }
  }

  private func makeOnAddNote() -> (String, WorkItem) -> Void {
    { [syncManager, currentUserId, undoManager] content, item in
      let note: Note
      switch item {
      case .task(let t, _):
        note = Note(content: content, createdBy: currentUserId, parentType: .task, parentId: t.id)
        t.notes.append(note)
        t.markPending()

      case .activity(let a, _):
        note = Note(content: content, createdBy: currentUserId, parentType: .activity, parentId: a.id)
        a.notes.append(note)
        a.markPending()
      }
      syncManager.requestSync()

      // Register undo action - soft-delete the newly created note with redo support
      undoManager?.registerUndo(withTarget: note) { [currentUserId, undoManager] note in
        note.softDelete(by: currentUserId)

        // Register redo action (restore the note)
        undoManager?.registerUndo(withTarget: note) { [currentUserId, undoManager] note in
          note.undoDelete()
          syncManager.requestSync()
          undoManager?.setActionName("Add Note")
        }
        undoManager?.setActionName("Add Note")
        syncManager.requestSync()
      }
      undoManager?.setActionName("Add Note")
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

      // Register undo action with redo support
      undoManager?.registerUndo(withTarget: note) { [currentUserId, undoManager] note in
        note.undoDelete()

        // Register redo action (re-delete the note)
        undoManager?.registerUndo(withTarget: note) { [currentUserId, undoManager] note in
          note.softDelete(by: currentUserId)
          syncManager.requestSync()
          undoManager?.setActionName("Delete Note")
        }
        undoManager?.setActionName("Delete Note")
        syncManager.requestSync()
      }
      undoManager?.setActionName("Delete Note")
    }
  }

  private func makeOnListingStageChanged() -> (Listing, ListingStage) -> Void {
    { [syncManager, undoManager] listing, newStage in
      // Capture previous stage before mutation
      let previousStage = listing.stage

      // Only proceed if stage is actually changing
      guard previousStage != newStage else { return }

      // Apply the change
      listing.stage = newStage
      listing.markPending()
      syncManager.requestSync()

      // Register undo action to restore previous stage with redo support
      undoManager?.registerUndo(withTarget: listing) { [previousStage, newStage, undoManager] listing in
        listing.stage = previousStage
        listing.markPending()

        // Register redo action (re-apply the new stage)
        undoManager?.registerUndo(withTarget: listing) { [newStage, undoManager] listing in
          listing.stage = newStage
          listing.markPending()
          syncManager.requestSync()
          undoManager?.setActionName("Change Stage")
        }
        undoManager?.setActionName("Change Stage")
        syncManager.requestSync()
      }
      undoManager?.setActionName("Change Stage")
    }
  }

  private func makeOnAddNoteToListing() -> (String, Listing) -> Void {
    { [syncManager, currentUserId, undoManager] content, listing in
      // Create and add the note
      let note = Note(content: content, createdBy: currentUserId, parentType: .listing, parentId: listing.id)
      listing.notes.append(note)
      syncManager.requestSync()

      // Register undo action - soft-delete the newly created note with redo support
      undoManager?.registerUndo(withTarget: note) { [currentUserId, undoManager] note in
        note.softDelete(by: currentUserId)

        // Register redo action (restore the note)
        undoManager?.registerUndo(withTarget: note) { [currentUserId, undoManager] note in
          note.undoDelete()
          syncManager.requestSync()
          undoManager?.setActionName("Add Note")
        }
        undoManager?.setActionName("Add Note")
        syncManager.requestSync()
      }
      undoManager?.setActionName("Add Note")
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
