//
//  WorkItemListContainer.swift
//  Dispatch
//
//  Generic container for Task/Activity list views
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI

struct WorkItemListContainer<Row: View, Destination: View>: View {

  // MARK: Lifecycle

  init(
    title: String,
    items: [WorkItem],
    currentUserId: UUID,
    userLookup: [UUID: User],
    isActivityList: Bool = false,
    embedInNavigationStack: Bool = true,
    @ViewBuilder rowBuilder: @escaping (WorkItem) -> Row,
    @ViewBuilder destination: @escaping (WorkItemRef) -> Destination
  ) {
    self.title = title
    self.items = items
    self.currentUserId = currentUserId
    self.userLookup = userLookup
    self.isActivityList = isActivityList
    self.embedInNavigationStack = embedInNavigationStack
    self.rowBuilder = rowBuilder
    destinationBuilder = destination
  }

  // MARK: Internal

  let title: String
  let items: [WorkItem]
  let currentUserId: UUID
  let userLookup: [UUID: User]
  let isActivityList: Bool
  let embedInNavigationStack: Bool
  @ViewBuilder let rowBuilder: (WorkItem) -> Row
  @ViewBuilder let destinationBuilder: (WorkItemRef) -> Destination

  var body: some View {
    if embedInNavigationStack {
      NavigationStack {
        mainScreen
      }
    } else {
      mainScreen
    }
  }

  // MARK: Private

  @State private var selectedFilter = AssignmentFilter.mine
  @EnvironmentObject private var lensState: LensState

  // Memoized computed results - only recalculated when dependencies change
  @State private var filteredItems: [WorkItem] = []
  @State private var groupedItems: [(section: DateSection, items: [WorkItem])] = []

  #if os(macOS)
  /// Tracks the currently focused work item ID for keyboard navigation
  @FocusState private var focusedItemID: UUID?
  #endif

  private var isEmpty: Bool {
    filteredItems.isEmpty
  }

  private var emptyTitle: String {
    isActivityList ? "No Activities" : "No Tasks"
  }

  private var emptyIcon: String {
    isActivityList ? DS.Icons.Entity.activity : DS.Icons.Entity.task
  }

  private var emptyDescription: String {
    switch selectedFilter {
    case .mine:
      isActivityList
        ? "Activities assigned to you will appear here"
        : "Tasks assigned to you will appear here"

    case .others:
      isActivityList
        ? "Activities assigned to others will appear here"
        : "Tasks assigned to others will appear here"

    case .unassigned:
      isActivityList
        ? "Activities available to claim will appear here"
        : "Tasks available to claim will appear here"
    }
  }

  /// Flat list of all work item IDs for keyboard navigation
  private var allItemIDs: [UUID] {
    groupedItems.flatMap { $0.items.map(\.id) }
  }

  private var mainScreen: some View {
    StandardScreen(title: title, layout: .column, scroll: .disabled) {
      VStack(spacing: 0) {
        // Filter Bar
        SegmentedFilterBar(selection: $selectedFilter) { filter in
          filter.displayName(forActivities: isActivityList)
        }
        .padding(.bottom, DS.Spacing.md)

        if isEmpty {
          emptyStateView
        } else {
          listView
        }
      }
    }
    #if os(macOS)
    .onMoveCommand { direction in
      handleMoveCommand(direction)
    }
    #endif
    // Memoization: recompute filtered/grouped items when dependencies change
    .onChange(of: items, initial: true) { _, _ in
      updateFilteredItems()
    }
    .onChange(of: selectedFilter) { _, _ in
      updateFilteredItems()
    }
    .onChange(of: lensState.audience) { _, _ in
      updateFilteredItems()
    }
  }

  private var listView: some View {
    List {
      ForEach(groupedItems, id: \.section) { section, sectionItems in
        Section {
          ForEach(sectionItems) { item in
            rowBuilder(item)
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets(
                top: 0,
                leading: 0,
                bottom: 0,
                trailing: DS.Spacing.md
              ))
          }
        } header: {
          DateSectionHeader(section: section)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .environment(\.defaultMinListRowHeight, 1)
    .pullToSearch()
  }

  private var emptyStateView: some View {
    ContentUnavailableView {
      Label(emptyTitle, systemImage: emptyIcon)
    } description: {
      Text(emptyDescription)
    }
    // Frame removed to use standard alignment or assumed context
    .frame(minHeight: 300) // Ensure it takes some vertical space in the absence of list
  }

  /// Recomputes filtered and grouped items from current state
  private func updateFilteredItems() {
    let newFiltered = items.filter { item in
      selectedFilter.matches(assigneeUserIds: item.assigneeUserIds, currentUserId: currentUserId) &&
        lensState.audience.matches(audiences: item.audiences)
    }
    filteredItems = newFiltered
    groupedItems = DateSection.sortedSections(from: newFiltered)
  }

  #if os(macOS)
  /// Handles arrow key navigation in the work items list
  private func handleMoveCommand(_ direction: MoveCommandDirection) {
    let ids = allItemIDs
    guard !ids.isEmpty else { return }

    switch direction {
    case .up:
      if
        let currentID = focusedItemID,
        let currentIndex = ids.firstIndex(of: currentID),
        currentIndex > 0
      {
        focusedItemID = ids[currentIndex - 1]
      } else {
        // No selection or at top - select first item
        focusedItemID = ids.first
      }

    case .down:
      if
        let currentID = focusedItemID,
        let currentIndex = ids.firstIndex(of: currentID),
        currentIndex < ids.count - 1
      {
        focusedItemID = ids[currentIndex + 1]
      } else if focusedItemID == nil {
        // No selection - select first item
        focusedItemID = ids.first
      }

    case .left, .right:
      // Left/right not used for vertical lists
      break

    @unknown default:
      break
    }
  }
  #endif

}

// MARK: - Preview

#Preview("Work Item List Container") {
  let sampleUser = User(name: "John Doe", email: "john@example.com", userType: .admin)
  let currentUserId = sampleUser.id

  let sampleTasks: [WorkItem] = [
    .task(TaskItem(
      title: "Review quarterly report",
      taskDescription: "Go through Q4 numbers",
      dueDate: Date(),
      declaredBy: currentUserId,
      assigneeUserIds: [currentUserId]
    ))
  ]

  WorkItemListContainer(
    title: "Tasks",
    items: sampleTasks,
    currentUserId: currentUserId,
    userLookup: [sampleUser.id: sampleUser],
    rowBuilder: { item in
      Text(item.title)
    },
    destination: { _ in
      Text("Detail View")
    }
  )
  .environmentObject(LensState())
}
