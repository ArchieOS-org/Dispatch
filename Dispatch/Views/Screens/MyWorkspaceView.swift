//
//  MyWorkspaceView.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-28.
//

import SwiftUI
import SwiftData

// Grouping structure moved to file scope (or public) to be accessible by child views
struct WorkspaceGroup: Identifiable {
    let id: UUID // Listing ID (or UUID() for general)
    let listing: Listing?
    var items: [WorkItem]
}

    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var lensState: LensState
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var activities: [Activity]
    
    @Binding var navigationPath: NavigationPath // If used in NavigationStack
    
    // MARK: - Filter Logic
    enum WorkspaceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case tasks = "Tasks"
        case activities = "Activities"
        
        var id: String { rawValue }
    }
    
    @State private var selectedFilter: WorkspaceFilter = .all

    var body: some View {
        ZStack {
            DS.Colors.Background.primary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DS.Spacing.sectionSpacing) {
                    // Header Area
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        // Title (Large, Things 3 style)
                        Text("My Workspace")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(DS.Colors.Text.primary)
                        
                        // Filter Bar
                        SegmentedFilterBar(selection: $selectedFilter)
                    }
                    .padding(.horizontal, DS.Spacing.Layout.pageMargin)
                    .padding(.top, DS.Spacing.Layout.topHeaderPadding)
                    
                    // Content
                    if groupedItems.isEmpty {
                        ContentUnavailableView {
                            Label(emptyTitle, systemImage: emptyIcon)
                        } description: {
                            Text(emptyDescription)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(groupedItems) { group in
                                ListingWorkspaceSection(group: group)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.Layout.pageMargin)
                        // Force refresh when filter changes to prevent stale groups
                        .id(selectedFilter)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Data Logic
    
    // Helper for Empty State
    private var emptyTitle: String {
        switch selectedFilter {
        case .all: return "No Items"
        case .tasks: return "No Tasks"
        case .activities: return "No Activities"
        }
    }
    
    private var emptyIcon: String {
        switch selectedFilter {
        case .all: return "tray"
        case .tasks: return DS.Icons.Entity.task
        case .activities: return DS.Icons.Entity.activity
        }
    }
    
    private var emptyDescription: String {
        switch selectedFilter {
        case .all: return "You have no claimed tasks or activities."
        case .tasks: return "You have no claimed tasks."
        case .activities: return "You have no claimed activities."
        }
    }
    
    private var groupedItems: [WorkspaceGroup] {
        var groups: [UUID: WorkspaceGroup] = [:]
        var generalItems: [WorkItem] = []
        
        guard let currentUserID = syncManager.currentUserID else {
            return []
        }
        
        // Filter by Current User AND Selected Filter AND Not Deleted AND Audience
        let relevantTasks = (selectedFilter == .all || selectedFilter == .tasks) 
            ? tasks.filter { 
                $0.claimedBy == currentUserID && 
                $0.status != .deleted &&
                lensState.audience.matches(audiences: $0.audiences)
            } 
            : []
            
        let relevantActivities = (selectedFilter == .all || selectedFilter == .activities) 
            ? activities.filter { 
                $0.claimedBy == currentUserID && 
                $0.status != .deleted &&
                lensState.audience.matches(audiences: $0.audiences)
            } 
            : []
        
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
        for i in 0..<sortedGroups.count {
            sortedGroups[i].items.sort { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
        }
        
        var result = sortedGroups
        
        // Add General section if needed
        if !generalItems.isEmpty {
            // Sort general items by due date too
            let sortedGeneral = generalItems.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
            result.append(WorkspaceGroup(id: UUID(), listing: nil, items: sortedGeneral))
        }
        
        return result
    }
}

struct ListingWorkspaceSection: View {
    let group: WorkspaceGroup
    @State private var isExpanded: Bool = true
    @EnvironmentObject private var actions: WorkItemActions
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Text.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    
                    if let listing = group.listing {
                        Text(listing.address)
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.Text.primary)
                        
                        Spacer()
                        
                        ProgressCircle(progress: listing.progress, size: 18)
                    } else {
                        Text("General / Unassigned")
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.Text.primary)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Items
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.items) { item in
                        NavigationLink(value: WorkItemRef.from(item)) {
                            WorkItemRow(
                                item: item,
                                claimState: .claimedByMe(user: User.mockCurrentUser), // Contextually implied "Me"
                                onComplete: { actions.onComplete(item) },
                                onEdit: {}, // TODO: Edit actions if needed
                                onDelete: {}, // TODO: Delete actions if needed
                                onClaim: { actions.onClaim(item) },
                                onRelease: { actions.onRelease(item) },
                                onRetrySync: {},
                                hideUserTag: true
                            )
                            .padding(.leading, 24)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// Mock user extension for preview/default
extension User {
    static var mockCurrentUser: User {
        User(id: UUID(), name: "Me", email: "me@dispatch.com", userType: .admin)
    }
}
