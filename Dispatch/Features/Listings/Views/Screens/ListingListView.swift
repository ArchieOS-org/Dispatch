//
//  ListingListView.swift
//  Dispatch
//
//  Main screen for displaying and managing listings
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftData
import SwiftUI

// MARK: - ListingGroup

/// A group of listings belonging to a single owner
private struct ListingGroup: Identifiable {
  let owner: User?
  let listings: [Listing]

  var id: String {
    owner?.id.uuidString ?? "unknown"
  }
}

// MARK: - ListingListView

struct ListingListView: View {

  // MARK: Internal

  var body: some View {
    mainScreen
      // MARK: - Alerts
      .alert("Delete Note?", isPresented: $showDeleteNoteAlert) {
        Button("Cancel", role: .cancel) {
          noteToDelete = nil
          itemForNoteDeletion = nil
        }
        Button("Delete", role: .destructive) {
          confirmDeleteNote()
        }
      } message: {
        Text("This note will be permanently deleted.")
      }
      .alert("Delete Subtask?", isPresented: $showDeleteSubtaskAlert) {
        Button("Cancel", role: .cancel) {
          subtaskToDelete = nil
          itemForSubtaskDeletion = nil
        }
        Button("Delete", role: .destructive) {
          confirmDeleteSubtask()
        }
      } message: {
        Text("This subtask will be permanently deleted.")
      }
      .sheet(isPresented: $showAddSubtaskSheet) {
        AddSubtaskSheet(title: $newSubtaskTitle) {
          if let item = itemForSubtaskAdd {
            addSubtask(to: item, title: newSubtaskTitle)
          }
          newSubtaskTitle = ""
          itemForSubtaskAdd = nil
          showAddSubtaskSheet = false
        }
      }
  }

  // MARK: Private

  private static let unauthenticatedUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

  @Query(sort: \Listing.address)
  private var allListingsRaw: [Listing]

  @Query private var users: [User]

  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var appState: AppState
  @Environment(\.modelContext) private var modelContext

  #if os(iOS)
  /// Collapsed by default to avoid duplication with tabViewSidebarHeader.
  @State private var stagesExpanded = false

  /// Check device type for iPad-specific UI.
  private var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
  }
  #endif

  @State private var showDeleteNoteAlert = false
  @State private var noteToDelete: Note?
  @State private var itemForNoteDeletion: WorkItem?

  @State private var showDeleteSubtaskAlert = false
  @State private var subtaskToDelete: Subtask?
  @State private var itemForSubtaskDeletion: WorkItem?

  @State private var showAddSubtaskSheet = false
  @State private var itemForSubtaskAdd: WorkItem?
  @State private var newSubtaskTitle = ""

  /// Filter out deleted listings
  private var allListings: [Listing] {
    allListingsRaw.filter { $0.status != .deleted }
  }

  /// Pre-computed user lookup dictionary for O(1) access
  private var userCache: [UUID: User] {
    Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
  }

  /// Listings grouped by owner, sorted by owner name
  private var groupedByOwner: [ListingGroup] {
    // Explicit typing helper
    let listings: [Listing] = allListings
    let grouped: [UUID: [Listing]] = Dictionary(grouping: listings) { (listing: Listing) in
      listing.ownedBy
    }

    let groups: [ListingGroup] = grouped.map { (key: UUID, value: [Listing]) -> ListingGroup in
      ListingGroup(owner: userCache[key], listings: value)
    }

    return groups.sorted { (a: ListingGroup, b: ListingGroup) -> Bool in
      let nameA = a.owner?.name ?? "~"
      let nameB = b.owner?.name ?? "~"
      return nameA < nameB
    }
  }

  /// Whether the list is empty
  private var isEmpty: Bool {
    allListings.isEmpty
  }

  /// Stage counts computed from active listings.
  private var stageCounts: [ListingStage: Int] {
    allListings.stageCounts()
  }

  private var currentUserId: UUID {
    syncManager.currentUserID ?? Self.unauthenticatedUserId
  }

  private var mainScreen: some View {
    StandardScreen(title: "Listings", layout: .column, scroll: .automatic) {
      VStack(spacing: 0) {
        // iPad fallback: Stage cards in collapsed DisclosureGroup.
        // tabViewSidebarHeader is hidden in tab bar mode, so we provide access here.
        // Collapsed by default to avoid duplication when sidebar is visible.
        #if os(iOS)
        if isIPad {
          DisclosureGroup("Stages", isExpanded: $stagesExpanded) {
            StageCardsHeader(
              stageCounts: stageCounts,
              onSelectStage: { stage in
                appState.dispatch(.setSelectedDestination(.stage(stage)))
              }
            )
          }
          .padding(.horizontal, DS.Spacing.md)
          .padding(.vertical, DS.Spacing.sm)
        }
        #endif

        if groupedByOwner.isEmpty {
          // Caller handles empty state
          ContentUnavailableView {
            Label("No Listings", systemImage: DS.Icons.Entity.listing)
          } description: {
            Text("Listings will appear here")
          }
        } else {
          StandardGroupedList(
            groupedByOwner,
            items: { $0.listings },
            header: { group in
              SectionHeader(group.owner?.name ?? "Unknown Owner")
            },
            row: { group, listing in
              ListRowLink(value: AppRoute.listing(listing.id)) {
                ListingRow(listing: listing, owner: group.owner)
              }
            }
          )
        }
      }
    } toolbarContent: {
      ToolbarItem(placement: .automatic) {
        EmptyView()
      }
    }
  }

  private func workItemDestination(for ref: WorkItemRef) -> some View {
    WorkItemResolverView(
      ref: ref,
      currentUserId: currentUserId,
      userLookup: userCache,
      availableUsers: users,
      onComplete: { item in toggleComplete(item) },
      onAssigneesChanged: { item, userIds in updateAssignees(item, userIds: userIds) },
      onEditNote: nil,
      onDeleteNote: { note, item in
        noteToDelete = note
        itemForNoteDeletion = item
        showDeleteNoteAlert = true
      },
      onAddNote: { content, item in addNote(to: item, content: content) },
      onToggleSubtask: { subtask in toggleSubtask(subtask) },
      onDeleteSubtask: { subtask, item in
        subtaskToDelete = subtask
        itemForSubtaskDeletion = item
        showDeleteSubtaskAlert = true
      },
      onAddSubtask: { item in
        itemForSubtaskAdd = item
        showAddSubtaskSheet = true
      }
    )
  }

  private func toggleComplete(_ item: WorkItem) {
    switch item {
    case .task(let task, _):
      task.status = task.status == .completed ? .open : .completed
      task.completedAt = task.status == .completed ? Date() : nil
      task.markPending()

    case .activity(let activity, _):
      activity.status = activity.status == .completed ? .open : .completed
      activity.completedAt = activity.status == .completed ? Date() : nil
      activity.markPending()
    }
    syncManager.requestSync()
  }

  private func updateAssignees(_ item: WorkItem, userIds: [UUID]) {
    let userIdSet = Set(userIds)

    switch item {
    case .task(let task, _):
      // Remove assignees no longer in list
      task.assignees.removeAll { !userIdSet.contains($0.userId) }
      // Add new assignees
      let existingUserIds = Set(task.assignees.map { $0.userId })
      for userId in userIds where !existingUserIds.contains(userId) {
        let assignee = TaskAssignee(
          taskId: task.id,
          userId: userId,
          assignedBy: currentUserId
        )
        assignee.task = task
        task.assignees.append(assignee)
      }
      task.markPending()

    case .activity(let activity, _):
      // Remove assignees no longer in list
      activity.assignees.removeAll { !userIdSet.contains($0.userId) }
      // Add new assignees
      let existingUserIds = Set(activity.assignees.map { $0.userId })
      for userId in userIds where !existingUserIds.contains(userId) {
        let assignee = ActivityAssignee(
          activityId: activity.id,
          userId: userId,
          assignedBy: currentUserId
        )
        assignee.activity = activity
        activity.assignees.append(assignee)
      }
      activity.markPending()
    }
    syncManager.requestSync()
  }

  private func addNote(to item: WorkItem, content: String) {
    switch item {
    case .task(let task, _):
      let note = Note(content: content, createdBy: currentUserId, parentType: .task, parentId: item.id)
      task.notes.append(note)
      task.markPending()

    case .activity(let activity, _):
      let note = Note(content: content, createdBy: currentUserId, parentType: .activity, parentId: item.id)
      activity.notes.append(note)
      activity.markPending()
    }
    syncManager.requestSync()
  }

  private func confirmDeleteNote() {
    guard let note = noteToDelete, let item = itemForNoteDeletion else { return }
    switch item {
    case .task(let task, _):
      task.notes.removeAll { $0.id == note.id }
      task.markPending()

    case .activity(let activity, _):
      activity.notes.removeAll { $0.id == note.id }
      activity.markPending()
    }
    modelContext.delete(note)
    noteToDelete = nil
    itemForNoteDeletion = nil
    syncManager.requestSync()
  }

  private func toggleSubtask(_ subtask: Subtask) {
    subtask.completed.toggle()
    syncManager.requestSync()
  }

  private func confirmDeleteSubtask() {
    guard let subtask = subtaskToDelete, let item = itemForSubtaskDeletion else { return }
    switch item {
    case .task(let task, _):
      task.subtasks.removeAll { $0.id == subtask.id }
      task.markPending()

    case .activity(let activity, _):
      activity.subtasks.removeAll { $0.id == subtask.id }
      activity.markPending()
    }
    modelContext.delete(subtask)
    subtaskToDelete = nil
    itemForSubtaskDeletion = nil
    syncManager.requestSync()
  }

  private func addSubtask(to item: WorkItem, title: String) {
    switch item {
    case .task(let task, _):
      let subtask = Subtask(title: title, parentType: .task, parentId: item.id)
      task.subtasks.append(subtask)
      task.markPending()

    case .activity(let activity, _):
      let subtask = Subtask(title: title, parentType: .activity, parentId: item.id)
      activity.subtasks.append(subtask)
      activity.markPending()
    }
    syncManager.requestSync()
  }
}

// MARK: - ListingListPreviewContainer

/// Container to inject sample data for previews
private struct ListingListPreviewContainer: View {

  // MARK: Internal

  var body: some View {
    ListingListView()
      .onAppear { insertSampleData() }
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext

  private func insertSampleData() {
    // Create sample owners
    let janeRealtor = User(
      name: "Jane Smith",
      email: "jane@realestate.com",
      userType: .realtor
    )
    let johnAgent = User(
      name: "John Anderson",
      email: "john@realestate.com",
      userType: .realtor
    )
    let sarahBroker = User(
      name: "Sarah Chen",
      email: "sarah@realestate.com",
      userType: .realtor
    )

    modelContext.insert(janeRealtor)
    modelContext.insert(johnAgent)
    modelContext.insert(sarahBroker)

    // Jane's listings - variety of states
    let listing1 = Listing(
      address: "123 Main Street",
      city: "Toronto",
      province: "ON",
      postalCode: "M5V 1A1",
      price: 899000,
      status: .active,
      ownedBy: janeRealtor.id,
      dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())
    )

    let listing2 = Listing(
      address: "456 Oak Avenue, Unit 12",
      city: "Toronto",
      province: "ON",
      postalCode: "M4Y 2B3",
      price: 1250000,
      status: .active,
      ownedBy: janeRealtor.id,
      dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) // Overdue
    )

    let listing3 = Listing(
      address: "789 Maple Road",
      city: "Mississauga",
      province: "ON",
      status: .pending,
      ownedBy: janeRealtor.id
      // No due date
    )

    // John's listings
    let listing4 = Listing(
      address: "1010 Yonge Street, PH2",
      city: "Toronto",
      province: "ON",
      postalCode: "M4W 2L1",
      price: 2500000,
      status: .active,
      ownedBy: johnAgent.id,
      dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
    )

    let listing5 = Listing(
      address: "222 Queen Street West",
      city: "Toronto",
      province: "ON",
      price: 750000,
      status: .active,
      ownedBy: johnAgent.id,
      dueDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) // Overdue
    )

    // Sarah's listings
    let listing6 = Listing(
      address: "55 Bloor Street East, Suite 1800",
      city: "Toronto",
      province: "ON",
      price: 3200000,
      listingType: .lease,
      status: .active,
      ownedBy: sarahBroker.id,
      dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
    )

    let listing7 = Listing(
      address: "100 Harbour Street",
      city: "Toronto",
      province: "ON",
      price: 1800000,
      status: .draft,
      ownedBy: sarahBroker.id
    )

    // Insert all listings
    for item in [listing1, listing2, listing3, listing4, listing5, listing6, listing7] {
      modelContext.insert(item)
    }

    // Add tasks to some listings for progress indication
    let task1 = TaskItem(
      title: "Schedule photography",
      taskDescription: "Book professional photos",
      status: .completed,
      declaredBy: janeRealtor.id
    )
    let task2 = TaskItem(
      title: "Update MLS",
      taskDescription: "Update listing details",
      status: .open,
      declaredBy: janeRealtor.id
    )
    listing1.tasks.append(task1)
    listing1.tasks.append(task2)

    let task3 = TaskItem(
      title: "Price review",
      taskDescription: "Review comparable sales",
      status: .completed,
      declaredBy: johnAgent.id
    )
    let task4 = TaskItem(
      title: "Virtual tour",
      taskDescription: "Create 3D walkthrough",
      status: .completed,
      declaredBy: johnAgent.id
    )
    let task5 = TaskItem(
      title: "Open house prep",
      taskDescription: "Prepare for weekend showing",
      status: .open,
      declaredBy: johnAgent.id
    )
    listing4.tasks.append(task3)
    listing4.tasks.append(task4)
    listing4.tasks.append(task5)

    try? modelContext.save()
  }
}

#Preview("Listing List - With Data") {
  ListingListPreviewContainer()
    .modelContainer(for: [
      Listing.self,
      User.self,
      TaskItem.self,
      Activity.self,
      Note.self,
      Subtask.self,
      StatusChange.self,
      TaskAssignee.self,
      ActivityAssignee.self
    ], inMemory: true)
    .environmentObject(SyncManager(mode: .preview))
    .environmentObject(LensState())
    .environmentObject(AppState(mode: .preview))
}

#Preview("Listing List - Empty") {
  ListingListView()
    .modelContainer(for: [Listing.self, User.self], inMemory: true)
    .environmentObject(SyncManager(mode: .preview))
    .environmentObject(LensState())
    .environmentObject(AppState(mode: .preview))
}
