//
//  MyWorkspaceView.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-28.
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftData
import SwiftUI

// MARK: - WorkspaceGroup

/// Grouping structure moved to file scope (or public) to be accessible by child views
struct WorkspaceGroup: Identifiable {
  let id: UUID // Listing ID (or stable generalGroupID for general)
  let listing: Listing?
  var items: [WorkItem]

  /// Stable ID for the General/Available section (avoids UUID() instability)
  static let generalGroupID = UUID()
}

// MARK: - MyWorkspaceView

struct MyWorkspaceView: View {

  // MARK: Internal

  enum WorkspaceFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case tasks = "Tasks"
    case activities = "Activities"

    var id: String {
      rawValue
    }
  }

  var body: some View {
    // Compute once to ensure stable values across the body
    let groups = groupedItems

    return StandardScreen(title: "My Workspace", layout: .column, scroll: .automatic) {
      VStack(spacing: DS.Spacing.sectionSpacing) {
        // Filter Bar
        SegmentedFilterBar(selection: $selectedFilter)
          .padding(.top, DS.Spacing.md)
          .padding(.bottom, DS.Spacing.sm)

        // Content
        if groups.isEmpty {
          ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyIcon)
          } description: {
            Text(emptyDescription)
          }
          .padding(.top, 40)
        } else {
          LazyVStack(spacing: 24) {
            ForEach(groups) { group in
              ListingWorkspaceSection(group: group)
            }
          }
        }
      }
      .padding(.bottom, DS.Spacing.xxl)
    }
  }

  // MARK: Private

  @EnvironmentObject private var syncManager: SyncManager
  @EnvironmentObject private var lensState: LensState
  @Environment(\.modelContext) private var modelContext
  @Query private var tasks: [TaskItem]
  @Query private var activities: [Activity]

  @State private var selectedFilter = WorkspaceFilter.all

  /// Helper for Empty State
  private var emptyTitle: String {
    switch selectedFilter {
    case .all: "No Items"
    case .tasks: "No Tasks"
    case .activities: "No Activities"
    }
  }

  private var emptyIcon: String {
    switch selectedFilter {
    case .all: "tray"
    case .tasks: DS.Icons.Entity.task
    case .activities: DS.Icons.Entity.activity
    }
  }

  private var emptyDescription: String {
    switch selectedFilter {
    case .all: "You have no assigned tasks or activities."
    case .tasks: "You have no assigned tasks."
    case .activities: "You have no assigned activities."
    }
  }

  private var groupedItems: [WorkspaceGroup] {
    var groups = [UUID: WorkspaceGroup]()
    var generalItems = [WorkItem]()

    guard let currentUserID = syncManager.currentUserID else {
      return []
    }

    // Filter by Current User AND Not Deleted AND Audience
    // Pre-filter to reduce complexity
    let allTasks: [TaskItem] = tasks
    let allActivities: [Activity] = activities

    let shouldShowTasks = (selectedFilter == .all || selectedFilter == .tasks)
    let relevantTasks: [TaskItem] =
      if shouldShowTasks {
        allTasks.filter { task in
          task.assigneeUserIds.contains(currentUserID) &&
            task.status != .deleted &&
            lensState.audience.matches(audiences: task.audiences)
        }
      } else {
        []
      }

    let shouldShowActivities = (selectedFilter == .all || selectedFilter == .activities)
    let relevantActivities: [Activity] =
      if shouldShowActivities {
        allActivities.filter { activity in
          activity.assigneeUserIds.contains(currentUserID) &&
            activity.status != .deleted &&
            lensState.audience.matches(audiences: activity.audiences)
        }
      } else {
        []
      }

    let allItems: [WorkItem] = relevantTasks.map { .task($0) } + relevantActivities.map { .activity($0) }

    for item in allItems {
      if let listingId = item.listingId {
        if groups[listingId] == nil {
          // Use the new accessor to safely get the listing
          if let listing = item.listing {
            groups[listingId] = WorkspaceGroup(id: listingId, listing: listing, items: [])
          } else {
            // Fallback if relation missing
            generalItems.append(item)
            continue
          }
        }
        groups[listingId]?.items.append(item)
      } else {
        generalItems.append(item)
      }
    }

    // Sort groups by progress maybe? Or alphabetical?
    var sortedGroups = groups.values.sorted { ($0.listing?.address ?? "") < ($1.listing?.address ?? "") }

    // Sort items within groups by due date
    for i in 0 ..< sortedGroups.count {
      sortedGroups[i].items.sort { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
    }

    var result = sortedGroups

    // Add General section if needed
    if !generalItems.isEmpty {
      // Sort general items by due date too
      let sortedGeneral = generalItems.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
      result.append(WorkspaceGroup(id: WorkspaceGroup.generalGroupID, listing: nil, items: sortedGeneral))
    }

    return result
  }
}

// MARK: - ListingWorkspaceSection

struct ListingWorkspaceSection: View {

  // MARK: Internal

  let group: WorkspaceGroup

  var body: some View {
    VStack(spacing: 0) {
      // Header - Split into two distinct tap zones
      HStack(spacing: 0) {
        // ZONE 1: Chevron - 44pt hit target, shifted left into gutter
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded.toggle()
          }
        } label: {
          Image(systemName: "chevron.right")
            .font(.system(size: chevronIconSize, weight: .semibold))
            .foregroundStyle(DS.Colors.Text.tertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -20) // Shift 20pt left into the 24pt gutter (44 - 24 = 20)
        #if os(iOS)
          .sensoryFeedback(.impact(flexibility: .soft), trigger: isExpanded)
        #endif
          .accessibilityLabel(chevronAccessibilityLabel)

        // ZONE 2: Listing Info - naturally starts at 24pt line (aligned with checkboxes)
        if let listing = group.listing {
          NavigationLink(value: AppRoute.listing(listing.id)) {
            HStack(spacing: 12) {
              Text(listing.address)
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.Text.primary)
                .lineLimit(1)

              Spacer()

              ProgressCircle(progress: listing.progress, size: 18)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(listing.address)
          .accessibilityHint("Opens listing details")
        } else {
          // General/Available
          HStack(spacing: 12) {
            Text("General / Available")
              .font(DS.Typography.headline)
              .foregroundStyle(DS.Colors.Text.primary)
            Spacer()
          }
          .frame(maxWidth: .infinity)
          .frame(minHeight: 44)
          .accessibilityHint("No listing details")
        }
      }
      .padding(.leading, DS.Spacing.workItemRowIndent) // Same 24pt indent as work items

      // Items
      if isExpanded {
        VStack(spacing: 0) {
          ForEach(group.items) { item in
            NavigationLink(value: AppRoute.workItem(WorkItemRef.from(item))) {
              WorkItemRow(
                item: item,
                userLookup: actions.userLookupDict,
                onComplete: { actions.onComplete(item) },
                onEdit: { },
                onDelete: { },
                onClaim: {
                  var newAssignees = item.assigneeUserIds
                  if !newAssignees.contains(actions.currentUserId) {
                    newAssignees.append(actions.currentUserId)
                  }
                  actions.onAssigneesChanged(item, newAssignees)
                },
                hideAssignees: true // In workspace, we know it's assigned to me
              )
              .workItemRowStyle()
            }
            .buttonStyle(.plain)
          }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  // MARK: Private

  /// Scaled chevron icon size for Dynamic Type support (base: 12pt)
  @ScaledMetric(relativeTo: .caption)
  private var chevronIconSize: CGFloat = 12

  @State private var isExpanded = true
  @EnvironmentObject private var actions: WorkItemActions

  /// Contextual accessibility label includes address for VoiceOver users
  private var chevronAccessibilityLabel: String {
    if let listing = group.listing {
      return isExpanded ? "Collapse \(listing.address)" : "Expand \(listing.address)"
    }
    return isExpanded ? "Collapse general items" : "Expand general items"
  }

}

/// Mock user extension for preview/default
extension User {
  static var mockCurrentUser: User {
    User(id: UUID(), name: "Me", email: "me@dispatch.com", userType: .admin)
  }
}

// MARK: - Previews

#Preview("My Workspace - With Items") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }(),
    setup: { context in
      // Seed standard data (Alice as owner, Bob as claimer)
      PreviewDataFactory.seed(context)

      // Add more tasks claimed by Bob for variety
      let listing = try? context.fetch(FetchDescriptor<Listing>()).first

      let taskUrgent = TaskItem(
        title: "Fix Broken Window",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      taskUrgent.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
      taskUrgent.syncState = .synced
      listing?.tasks.append(taskUrgent)

      let activityScheduled = Activity(
        title: "Schedule Inspection",
        declaredBy: PreviewDataFactory.aliceID,
        listingId: listing?.id,
        assigneeUserIds: [PreviewDataFactory.bobID]
      )
      activityScheduled.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
      activityScheduled.syncState = .synced
      listing?.activities.append(activityScheduled)
    }
  ) { _ in
    MyWorkspaceView()
      .environmentObject(WorkItemActions(
        currentUserId: PreviewDataFactory.bobID,
        userLookup: { _ in nil }
      ))
  }
}

#Preview("My Workspace - Empty") {
  PreviewShell(
    syncManager: {
      let sm = SyncManager(mode: .preview)
      sm.currentUserID = PreviewDataFactory.bobID
      return sm
    }()
  ) { _ in
    MyWorkspaceView()
      .environmentObject(WorkItemActions(
        currentUserId: PreviewDataFactory.bobID,
        userLookup: { _ in nil }
      ))
  }
}

#Preview("My Workspace - Tasks Only Filter") {
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
    MyWorkspaceView()
      .environmentObject(WorkItemActions(
        currentUserId: PreviewDataFactory.bobID,
        userLookup: { _ in nil }
      ))
  }
}

#Preview("Listing Section - Expanded") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)
    }
  ) { context in
    let listing = try? context.fetch(FetchDescriptor<Listing>()).first

    let group = WorkspaceGroup(
      id: listing?.id ?? UUID(),
      listing: listing,
      items: [
        .task(TaskItem(
          title: "Sample Task 1",
          status: .open,
          declaredBy: PreviewDataFactory.aliceID,
          listingId: listing?.id
        )),
        .task(TaskItem(
          title: "Sample Task 2 - Overdue",
          status: .open,
          declaredBy: PreviewDataFactory.aliceID,
          listingId: listing?.id
        )),
        .activity(Activity(
          title: "Follow Up Call",
          declaredBy: PreviewDataFactory.aliceID,
          listingId: listing?.id
        ))
      ]
    )

    NavigationStack {
      List {
        ListingWorkspaceSection(group: group)
      }
      .listStyle(.plain)
    }
    .environmentObject(WorkItemActions(
      currentUserId: PreviewDataFactory.bobID,
      userLookup: { _ in nil }
    ))
  }
}

#Preview("Listing Section - General/Available") {
  PreviewShell { _ in
    let group = WorkspaceGroup(
      id: UUID(),
      listing: nil,
      items: [
        .task(TaskItem(
          title: "General Task - No Listing",
          status: .open,
          declaredBy: PreviewDataFactory.aliceID,
          listingId: nil
        )),
        .activity(Activity(
          title: "Team Meeting",
          declaredBy: PreviewDataFactory.aliceID,
          listingId: nil
        ))
      ]
    )

    NavigationStack {
      List {
        ListingWorkspaceSection(group: group)
      }
      .listStyle(.plain)
    }
    .environmentObject(WorkItemActions(
      currentUserId: PreviewDataFactory.bobID,
      userLookup: { _ in nil }
    ))
  }
}
