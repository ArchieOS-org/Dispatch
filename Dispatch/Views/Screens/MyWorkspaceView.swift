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

struct MyWorkspaceView: View {
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var activities: [Activity]
    
    @Binding var navigationPath: NavigationPath // If used in NavigationStack
    
    var body: some View {
        ZStack {
            DS.Colors.Background.primary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DS.Spacing.sectionSpacing) {
                    // Title (Large, Things 3 style)
                    HStack {
                        Text("My Workspace")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(DS.Colors.Text.primary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.Layout.pageMargin)
                    .padding(.top, DS.Spacing.Layout.topHeaderPadding)
                    
                    // Content
                    LazyVStack(spacing: 24) {
                        ForEach(groupedItems) { group in
                            ListingWorkspaceSection(group: group)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.Layout.pageMargin)
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Data Logic
    
    private var groupedItems: [WorkspaceGroup] {
        var groups: [UUID: WorkspaceGroup] = [:]
        var generalItems: [WorkItem] = []
        
        guard let currentUserID = syncManager.currentUserID else {
            return []
        }
        
        // Filter by Current User
        let relevantTasks = tasks.filter { $0.claimedBy == currentUserID }
        let relevantActivities = activities.filter { $0.claimedBy == currentUserID }
        
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
        let sortedGroups = groups.values.sorted { ($0.listing?.address ?? "") < ($1.listing?.address ?? "") }
        
        var result = sortedGroups
        
        // Add General section if needed
        if !generalItems.isEmpty {
            result.append(WorkspaceGroup(id: UUID(), listing: nil, items: generalItems))
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
