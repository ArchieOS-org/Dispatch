//
//  WorkItemListContainer.swift
//  Dispatch
//
//  Generic container for Task/Activity list views
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI

struct WorkItemListContainer<Row: View, Destination: View>: View {
    let title: String
    let items: [WorkItem]
    let currentUserId: UUID
    let userLookup: (UUID) -> User?
    let isActivityList: Bool
    let embedInNavigationStack: Bool
    @ViewBuilder let rowBuilder: (WorkItem, ClaimState) -> Row
    @ViewBuilder let destinationBuilder: (WorkItemRef) -> Destination

    @State private var selectedFilter: ClaimFilter = .mine
    @EnvironmentObject private var lensState: LensState

    init(
        title: String,
        items: [WorkItem],
        currentUserId: UUID,
        userLookup: @escaping (UUID) -> User?,
        isActivityList: Bool = false,
        embedInNavigationStack: Bool = true,
        @ViewBuilder rowBuilder: @escaping (WorkItem, ClaimState) -> Row,
        @ViewBuilder destination: @escaping (WorkItemRef) -> Destination
    ) {
        self.title = title
        self.items = items
        self.currentUserId = currentUserId
        self.userLookup = userLookup
        self.isActivityList = isActivityList
        self.embedInNavigationStack = embedInNavigationStack
        self.rowBuilder = rowBuilder
        self.destinationBuilder = destination
    }

    // MARK: - Computed Properties

    private var filteredItems: [WorkItem] {
        items.filter { item in
            selectedFilter.matches(claimedBy: item.claimedBy, currentUserId: currentUserId) &&
            lensState.audience.matches(audiences: item.audiences)
        }
    }

    private var groupedItems: [(section: DateSection, items: [WorkItem])] {
        DateSection.sortedSections(from: filteredItems)
    }

    private var isEmpty: Bool {
        filteredItems.isEmpty
    }

    // MARK: - Body

    var body: some View {
        if embedInNavigationStack {
            NavigationStack {
                mainScreen

            }
        } else {
            mainScreen
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .filterMine)) { _ in
            selectedFilter = .mine
        }
        .onReceive(NotificationCenter.default.publisher(for: .filterOthers)) { _ in
            selectedFilter = .others
        }
        .onReceive(NotificationCenter.default.publisher(for: .filterUnclaimed)) { _ in
            selectedFilter = .unclaimed
        }
    }

    // MARK: - Subviews

    private var listView: some View {
        List {
            ForEach(groupedItems, id: \.section) { section, sectionItems in
                Section {
                    ForEach(sectionItems) { item in
                        rowBuilder(item, item.claimState(currentUserId: currentUserId, userLookup: userLookup))
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
        ))
    ]

    WorkItemListContainer(
        title: "Tasks",
        items: sampleTasks,
        currentUserId: currentUserId,
        userLookup: { _ in sampleUser },
        rowBuilder: { item, claimState in
            Text(item.title)
        },
        destination: { _ in
            Text("Detail View")
        }
    )
    .environmentObject(SearchPresentationManager())
    .environmentObject(LensState())
}
