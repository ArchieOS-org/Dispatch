//
//  MyWorkspaceView.swift
//  Dispatch
//
//  Created by Noah Deskin on 2025-12-28.
//

import SwiftUI
import SwiftData

struct MyWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var activities: [Activity]
    
    // We need the current user to filter.
    // Assuming we have a way to get the current user ID. 
    // Usually this would be passed in or available via environment.
    // For now, I will use a computed property that filters by local user if available, or just all for demo if needed.
    // Using the standard `DataManager.shared.currentUser` pattern if it exists, or assuming a specific User ID context.
    // Better: Fetch all and filter in memory since we don't have dynamic @Query predicates for "currentUser" easily without passing it in.
    
    // Grouping structure
    struct WorkspaceGroup: Identifiable {
        let id: UUID // Listing ID (or UUID() for general)
        let listing: Listing?
        var items: [WorkItem]
    }
    
    @Binding var navigationPath: NavigationPath // If used in NavigationStack
    
    var body: some View {
        NavigationStack { // Internal stack or rely on parent? Usually views are pushed.
            ZStack {
                DS.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        // Title (Large, Things 3 style)
                        HStack {
                            Text("My Workspace")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(DS.Colors.Text.primary)
                            Spacer()
                        }
                        .padding(.horizontal, DS.Layout.pageMargin)
                        .padding(.top, DS.Layout.topHeaderPadding)
                        
                        // Content
                        LazyVStack(spacing: 24) {
                            ForEach(groupedItems) { group in
                                ListingWorkspaceSection(group: group)
                            }
                        }
                        .padding(.horizontal, DS.Layout.pageMargin)
                    }
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    // MARK: - Data Logic
    
    // TODO: Connect to actual Current User.
    // For now, I will assume we filter for *any* claimed item for demonstration, or add a TODO.
    // Actually, checking `WorkItemListContainer`, it typically filters.
    // I will filter items where `claimedBy != nil`.
    
    private var groupedItems: [WorkspaceGroup] {
        var groups: [UUID: WorkspaceGroup] = [:]
        var generalItems: [WorkItem] = []
        
        // Process Tasks
        // NOTE: In a real app we'd filter by `claimedBy == currentUser.id`.
        // Inspecting Schema: TaskItem has `claimedBy: UUID?`.
        let relevantTasks = tasks.filter { $0.claimedBy != nil }
        let relevantActivities = activities.filter { $0.claimedBy != nil }
        
        let allItems: [WorkItem] = relevantTasks.map { .task($0) } + relevantActivities.map { .activity($0) }
        
        for item in allItems {
            if let listingId = item.listingId {
                if groups[listingId] == nil {
                    // We need the listing object. 
                    // Since specific item has it? `item.listing` property?
                    // TaskItem definition has `var listing: Listing?`.
                    // We can try to grab it from the item.
                    let listing: Listing? = {
                        switch item {
                        case .task(let t): return t.listing
                        case .activity(let a): return a.listing
                        }
                    }()
                    
                    if let listing = listing {
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
                        
                        // Progress Pill? Or simple text?
                        // User mentioned "progress pill" in plan.
                        // Let's use a small custom view or existing component.
                        // ListingRow has ProgressCircle.
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
                        // Divider logic handled by list or custom?
                        // User wants "no separators", strict Things 3 style.
                        WorkItemRow(
                            item: item,
                            claimState: .claimedByMe(user: User.mockCurrentUser), // Assuming it's mine since it's "My Workspace"
                            onComplete: { /* toggle status */ }, // Needs wiring
                            onEdit: {},
                            onDelete: {},
                            onClaim: {},
                            onRelease: {},
                            onRetrySync: {}
                        )
                        .padding(.leading, 24) // Indent items slightly? Or flush? Things 3 indents items under headers.
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
