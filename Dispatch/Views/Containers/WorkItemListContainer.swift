//
//  WorkItemListContainer.swift
//  Dispatch
//
//  Generic container for Task/Activity list views
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A reusable container for TaskListView and ActivityListView that provides:
/// - NavigationStack wrapper with title
/// - Segmented filter bar (My/Others'/Unclaimed)
/// - Date-based sectioned list (Overdue/Today/Tomorrow/Upcoming/No Due Date)
/// - Pull-to-refresh functionality
/// - Custom row rendering via @ViewBuilder
/// - Navigation destination using WorkItemRef for crash-safe navigation
struct WorkItemListContainer<Row: View, Destination: View>: View {
    let title: String
    let items: [WorkItem]
    let currentUserId: UUID
    let userLookup: (UUID) -> User?
    let onRefresh: () async -> Void
    let isActivityList: Bool
    @ViewBuilder let rowBuilder: (WorkItem, ClaimState) -> Row
    @ViewBuilder let destinationBuilder: (WorkItemRef) -> Destination

    @State private var selectedFilter: ClaimFilter = .mine

    init(
        title: String,
        items: [WorkItem],
        currentUserId: UUID,
        userLookup: @escaping (UUID) -> User?,
        onRefresh: @escaping () async -> Void,
        isActivityList: Bool = false,
        @ViewBuilder rowBuilder: @escaping (WorkItem, ClaimState) -> Row,
        @ViewBuilder destination: @escaping (WorkItemRef) -> Destination
    ) {
        self.title = title
        self.items = items
        self.currentUserId = currentUserId
        self.userLookup = userLookup
        self.onRefresh = onRefresh
        self.isActivityList = isActivityList
        self.rowBuilder = rowBuilder
        self.destinationBuilder = destination
    }

    // MARK: - Computed Properties

    /// Items filtered by the selected claim filter
    private var filteredItems: [WorkItem] {
        items.filter { item in
            selectedFilter.matches(claimedBy: item.claimedBy, currentUserId: currentUserId)
        }
    }

    /// Filtered items grouped and sorted by date section
    private var groupedItems: [(section: DateSection, items: [WorkItem])] {
        DateSection.sortedSections(from: filteredItems)
    }

    /// Whether the filtered list is empty
    private var isEmpty: Bool {
        filteredItems.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                SegmentedFilterBar(selection: $selectedFilter) { filter in
                    filter.displayName(forActivities: isActivityList)
                }

                // Content
                if isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle(title)
            .refreshable {
                await onRefresh()
            }
            .navigationDestination(for: WorkItemRef.self) { ref in
                destinationBuilder(ref)
            }
        }
    }

    // MARK: - Subviews

    private var listView: some View {
        List {
            ForEach(groupedItems, id: \.section) { section, sectionItems in
                Section {
                    ForEach(sectionItems) { item in
                        rowBuilder(item, item.claimState(currentUserId: currentUserId, userLookup: userLookup))
                    }
                } header: {
                    DateSectionHeader(section: section)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyIcon)
        } description: {
            Text(emptyDescription)
        }
        .frame(maxHeight: .infinity)
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
            return isActivityList
                ? "Activities you claim will appear here"
                : "Tasks you claim will appear here"
        case .others:
            return isActivityList
                ? "Activities claimed by others will appear here"
                : "Tasks claimed by others will appear here"
        case .unclaimed:
            return isActivityList
                ? "Unclaimed activities will appear here"
                : "Unclaimed tasks will appear here"
        }
    }
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
            priority: .high,
            declaredBy: currentUserId,
            claimedBy: currentUserId
        )),
        .task(TaskItem(
            title: "Prepare presentation",
            taskDescription: "Create slides for meeting",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            priority: .medium,
            declaredBy: currentUserId,
            claimedBy: currentUserId
        )),
        .task(TaskItem(
            title: "Overdue task",
            taskDescription: "This is overdue",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            priority: .urgent,
            declaredBy: currentUserId,
            claimedBy: currentUserId
        ))
    ]

    WorkItemListContainer(
        title: "Tasks",
        items: sampleTasks,
        currentUserId: currentUserId,
        userLookup: { _ in sampleUser },
        onRefresh: { try? await Task.sleep(nanoseconds: 1_000_000_000) },
        rowBuilder: { item, claimState in
            WorkItemRow(
                item: item,
                claimState: claimState,
                onComplete: {},
                onEdit: {},
                onDelete: {},
                onClaim: {},
                onRelease: {}
            )
        },
        destination: { _ in
            Text("Detail View")
        }
    )
}
