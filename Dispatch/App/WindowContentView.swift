//
//  WindowContentView.swift
//  Dispatch
//
//  Wrapper view that owns per-window state.
//  SwiftUI creates new @State storage for each window instance.
//

import SwiftUI
import SwiftData

/// Wrapper view that owns per-window state.
///
/// This view exists specifically to hold `@State` properties that should be
/// isolated per-window on macOS. When placed inside a WindowGroup, SwiftUI
/// allocates new storage for each window that opens.
///
/// **Why not put this in DispatchApp?**
/// Property wrappers like `@State` can't be used directly in the App struct's
/// body - they must be in a View. This wrapper view solves that.
struct WindowContentView: View {

  // MARK: Internal

  // MARK: - Properties

  /// Reference to the shared app state (injected, not per-window)
  let appState: AppState

  /// Debug test harness binding (shared for simplicity)
  @Binding var showTestHarness: Bool

  // MARK: - Body

  var body: some View {
    Group {
      if DispatchApp.isUITesting || appState.authManager.isAuthenticated {
        if DispatchApp.isUITesting || syncManager.currentUser != nil {
          AppShellView()
        } else {
          OnboardingLoadingView()
        }
      } else {
        LoginView()
      }
    }
    .animation(.easeInOut, value: appState.authManager.isAuthenticated)
    .animation(.easeInOut, value: syncManager.currentUser != nil)
    #if os(macOS)
    // Inject per-window state into environment (macOS only)
    .environment(windowUIState)
    #endif
    #if DEBUG
    .sheet(isPresented: $showTestHarness) {
      SyncTestHarness()
        .environmentObject(SyncManager.shared)
    }
    #if os(iOS)
    .onShake {
      showTestHarness = true
    }
    #endif
    #endif
  }

  // MARK: Private

  /// Observed sync manager for currentUser changes
  @EnvironmentObject private var syncManager: SyncManager

  #if os(macOS)
  /// Per-window UI state - each window gets its own instance
  /// This is the key to multi-window state isolation
  @State private var windowUIState = WindowUIState()
  #endif

}

// MARK: - AppShellView

/// The top-level application shell.
/// Owns the Window Chrome Policy, Global Navigation Containers, and Global State Injection.
struct AppShellView: View {

  // swiftlint:disable:next force_unwrapping
  private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var syncManager: SyncManager
  @Environment(\.modelContext) private var modelContext

  @StateObject private var workItemActions = WorkItemActions()
  @StateObject private var overlayState = AppOverlayState()

  @Query private var users: [User]

  private var userCache: [UUID: User] {
    Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
  }

  private var currentUserId: UUID {
    syncManager.currentUserID ?? Self.unauthenticatedUserId
  }

  var body: some View {
    RootView()
      .applyMacWindowPolicy()
    #if os(macOS)
      .windowToolbarFullScreenVisibility(.visible)
    #endif
      .environmentObject(workItemActions)
      .environmentObject(overlayState)
      .environmentObject(appState.lensState)
      .onAppear { updateWorkItemActions() }
      .onChange(of: currentUserId) { _, _ in updateWorkItemActions() }
      .onChange(of: userCache) { _, _ in updateWorkItemActions() }
  }

  private func updateWorkItemActions() {
    workItemActions.currentUserId = currentUserId
    workItemActions.userLookup = { [userCache] id in userCache[id] }
    workItemActions.userLookupDict = userCache
    workItemActions.availableUsers = users
    workItemActions.onComplete = makeOnComplete()
    workItemActions.onAssigneesChanged = makeOnAssigneesChanged()
    workItemActions.onAddNote = makeOnAddNote()
    workItemActions.onDeleteNote = { [syncManager, currentUserId] note, _ in
      note.softDelete(by: currentUserId)
      syncManager.requestSync()
    }
    workItemActions.onClaim = makeOnClaim()
  }

  private func makeOnComplete() -> (WorkItem) -> Void {
    { [syncManager] item in
      switch item {
      case .task(let t, _):
        t.status = t.status == .completed ? .open : .completed
        t.completedAt = t.status == .completed ? Date() : nil
        t.markPending()

      case .activity(let a, _):
        a.status = a.status == .completed ? .open : .completed
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

      case .activity(let a, _):
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
      }
      syncManager.requestSync()
    }
  }

  private func makeOnAddNote() -> (String, WorkItem) -> Void {
    { [syncManager, currentUserId] content, item in
      switch item {
      case .task(let t, _):
        let n = Note(
          content: content,
          createdBy: currentUserId,
          parentType: .task,
          parentId: t.id
        )
        t.notes.append(n)
        t.markPending()

      case .activity(let a, _):
        let n = Note(
          content: content,
          createdBy: currentUserId,
          parentType: .activity,
          parentId: a.id
        )
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
}

// MARK: - Previews

#Preview("Authenticated") {
  WindowContentView(
    appState: AppState(mode: .preview),
    showTestHarness: .constant(false)
  )
  .environmentObject(SyncManager.shared)
}

#Preview("Login View") {
  WindowContentView(
    appState: AppState(mode: .preview),
    showTestHarness: .constant(false)
  )
  .environmentObject(SyncManager.shared)
}

#if DEBUG
#Preview("Test Harness") {
  WindowContentView(
    appState: AppState(mode: .preview),
    showTestHarness: .constant(true)
  )
  .environmentObject(SyncManager.shared)
}
#endif
