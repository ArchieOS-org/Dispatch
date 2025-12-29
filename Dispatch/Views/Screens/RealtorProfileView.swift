//
//  RealtorProfileView.swift
//  Dispatch
//
//  Created by Claude on 2025-12-28.
//

import SwiftUI
import SwiftData

/// Detailed profile view for a realtor.
/// Shows contact info, active listings, and global activity history.
struct RealtorProfileView: View {
    // MARK: - Properties

    let user: User

    // MARK: - Queries

    /// Fetch listings owned by this user
    @Query private var listings: [Listing]
    
    /// Fetch tasks claimed by this user
    @Query private var tasks: [TaskItem]
    
    /// Fetch activities claimed by this user
    @Query private var activities: [Activity]

    // MARK: - Filtered Properties

    private var userListings: [Listing] {
        listings.filter { $0.owner?.id == user.id && $0.status != .deleted }
    }

    private var recentActivity: [WorkItem] {
        var items: [WorkItem] = []
        
        // Add tasks
        let userTasks = tasks.filter { 
            ($0.claimedByUser?.id == user.id || $0.declaredBy == user.id) && $0.status != .deleted 
        }
        items.append(contentsOf: userTasks.map { WorkItem.task($0) })
        
        // Add activities
        let userActivities = activities.filter {
            ($0.claimedByUser?.id == user.id || $0.declaredBy == user.id) && $0.status != .deleted
        }
        items.append(contentsOf: userActivities.map { WorkItem.activity($0) })
        
        // Sort by most recently updated
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Environment

    @EnvironmentObject private var lensState: LensState
    @EnvironmentObject private var actions: WorkItemActions
    @State private var showEditSheet = false

    // MARK: - Body

    var body: some View {
        StandardPageLayout(title: "") {
            LazyVStack(spacing: DS.Spacing.sectionSpacing) {
                // Profile Header
                profileHeader

                // Active Listings Section
                if !userListings.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        sectionHeader("Active Listings (\(userListings.count))")
                        ForEach(userListings) { listing in
                            // Reuse ListingRow if available, but for now we'll inline a simple row 
                            // or verify if we can access ListingRow. ListingRow is internal to ListingListView usually.
                            // To keep it simple and safe, we'll use a standard navigation link wrapper.
                            NavigationLink(value: listing) {
                                ListingRowView(listing: listing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.Layout.pageMargin)
                }

                // Recent Activity Section
                if !recentActivity.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        sectionHeader("Recent Activity")
                        ForEach(recentActivity) { item in
                            // WorkItemRow needs to be wrapped in NavigationLink for navigation
                            NavigationLink(value: WorkItemRef.from(item)) {
                                WorkItemRow(
                                    item: item,
                                    claimState: item.claimState(currentUserId: actions.currentUserId, userLookup: actions.userLookup),
                                    onComplete: { actions.onComplete(item) },
                                    onEdit: {}, // Edit not needed here
                                    onDelete: {}, // Delete not needed here
                                    onClaim: { actions.onClaim(item) },
                                    onRelease: { actions.onRelease(item) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.Layout.pageMargin)
                }
            }
            .padding(.bottom, DS.Spacing.xxl) // Bottom padding for scrolling
        } headerActions: {
            Button("Edit") {
                showEditSheet = true
            }
            .font(DS.Typography.bodySecondary)
            .buttonStyle(.plain)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline) // Hide default large title when scrolling
        #endif
        .sheet(isPresented: $showEditSheet) {
            EditRealtorSheet(user: user)
        }
    }

    // MARK: - Subviews

    private var profileHeader: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Avatar
            Circle()
                .fill(DS.Colors.Background.secondary)
                .frame(width: 100, height: 100)
                .overlay {
                    if let avatarData = user.avatar, let pImage = PlatformImage.from(data: avatarData) {
                        Image(platformImage: pImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                    } else {
                        Text(user.initials)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(DS.Colors.Text.secondary)
                    }
                }

            VStack(spacing: DS.Spacing.xs) {
                Text(user.name)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.Text.primary)

                Text(user.userType.rawValue.capitalized)
                    .font(DS.Typography.bodySecondary)
                    .foregroundStyle(DS.Colors.Text.tertiary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.Background.tertiary)
                    .clipShape(Capsule())
            }

            // Quick Actions (Placeholders per user feedback)
            HStack(spacing: DS.Spacing.lg) {
                actionButton(icon: "envelope.fill", label: "Email") {
                    // Placeholder
                }
                actionButton(icon: "phone.fill", label: "Call") {
                    // Placeholder
                }
                actionButton(icon: "message.fill", label: "Slack") {
                    // Placeholder
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xl)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(DS.Colors.Background.tertiary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(DS.Colors.Text.primary)
                    }
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.Text.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.headline)
            .foregroundStyle(DS.Colors.Text.secondary)
            .textCase(.uppercase)
            .padding(.top, DS.Spacing.md)
    }
}

// MARK: - Helper Views

/// Recreating a simplified ListingRow for the profile view 
/// (Since ListingRow is likely internal to ListingListView or we want a specific style here)
private struct ListingRowView: View {
    let listing: Listing
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon
            Image(systemName: DS.Icons.Entity.listingFill)
                .font(.title2)
                .foregroundColor(DS.Colors.Text.tertiary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.address)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.Text.primary)
                
                Text("\(listing.city), \(listing.province)")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.Text.secondary)
            }
            
            Spacer()
            
            // Status Pill
            Text(listing.status.rawValue.capitalized)
                .font(DS.Typography.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DS.Colors.Background.tertiary)
                .clipShape(Capsule())
        }
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }
}
