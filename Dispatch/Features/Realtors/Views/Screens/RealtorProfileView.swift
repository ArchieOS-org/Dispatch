//
//  RealtorProfileView.swift
//  Dispatch
//
//  Created by Claude on 2025-12-28.
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftData
import SwiftUI

// MARK: - RealtorProfileView

/// Detailed profile view for a realtor.
struct RealtorProfileView: View {

  // MARK: Internal

  let user: User

  var body: some View {
    StandardScreen(title: user.name, layout: .column, scroll: .automatic) {
      content
    } toolbarContent: {
      ToolbarItem(placement: .primaryAction) {
        Button("Edit") {
          showEditSheet = true
        }
      }
    }
    .sheet(isPresented: $showEditSheet) {
      EditRealtorSheet(user: user)
    }
  }

  // MARK: Private

  @Query private var allProperties: [Property]
  @Query private var listings: [Listing]
  @Query private var tasks: [TaskItem]
  @Query private var activities: [Activity]

  @EnvironmentObject private var lensState: LensState
  @EnvironmentObject private var actions: WorkItemActions
  @State private var showEditSheet = false

  private var userProperties: [Property] {
    allProperties.filter { $0.ownedBy == user.id && $0.deletedAt == nil }
  }

  private var userListings: [Listing] {
    listings.filter { $0.owner?.id == user.id && $0.status != .deleted }
  }

  private var recentActivity: [WorkItem] {
    var items = [WorkItem]()

    let userTasks = tasks.filter {
      ($0.claimedByUser?.id == user.id || $0.declaredBy == user.id) && $0.status != .deleted
    }
    items.append(contentsOf: userTasks.map { WorkItem.task($0) })

    let userActivities = activities.filter {
      ($0.claimedByUser?.id == user.id || $0.declaredBy == user.id) && $0.status != .deleted
    }
    items.append(contentsOf: userActivities.map { WorkItem.activity($0) })

    return items.sorted { $0.updatedAt > $1.updatedAt }
  }

  private var content: some View {
    LazyVStack(spacing: DS.Spacing.sectionSpacing) {
      // Profile Header
      profileHeader

      // Properties Section
      if !userProperties.isEmpty {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
          sectionHeader("Properties (\(userProperties.count))")
          ForEach(userProperties) { property in
            NavigationLink(value: AppRoute.property(property.id)) {
              PropertyRowView(property: property)
            }
            .buttonStyle(.plain)
          }
        }
      }

      // Active Listings Section
      if !userListings.isEmpty {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
          sectionHeader("Active Listings (\(userListings.count))")
          ForEach(userListings) { listing in
            NavigationLink(value: AppRoute.listing(listing.id)) {
              ListingRowView(listing: listing)
            }
            .buttonStyle(.plain)
          }
        }
      }

      // Recent Activity Section
      if !recentActivity.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          sectionHeader("Recent Activity")
          ForEach(recentActivity) { item in
            NavigationLink(value: AppRoute.workItem(WorkItemRef.from(item))) {
              WorkItemRow(
                item: item,
                claimState: item.claimState(currentUserId: actions.currentUserId, userLookup: actions.userLookup),
                onComplete: { actions.onComplete(item) },
                onEdit: { },
                onDelete: { },
                onClaim: { actions.onClaim(item) },
                onRelease: { actions.onRelease(item) },
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(.bottom, DS.Spacing.xxl)
  }

  private var profileHeader: some View {
    VStack(spacing: DS.Spacing.lg) {
      // Avatar
      Circle()
        .fill(DS.Colors.Background.secondary)
        .frame(width: 80, height: 80)
        .overlay {
          if let avatarData = user.avatar, let pImage = PlatformImage.from(data: avatarData) {
            Image(platformImage: pImage)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .clipShape(Circle())
          } else {
            Text(user.initials)
              .font(.system(size: 32, weight: .medium))
              .foregroundStyle(DS.Colors.Text.secondary)
          }
        }

      VStack(spacing: DS.Spacing.xs) {
        Text(user.userType.rawValue.capitalized)
          .font(DS.Typography.bodySecondary)
          .foregroundStyle(DS.Colors.Text.tertiary)
          .padding(.leading, DS.Spacing.sm)
          .padding(.trailing, DS.Spacing.sm)
          .padding(.vertical, DS.Spacing.xxs)
          .background(DS.Colors.Background.tertiary)
          .clipShape(Capsule())
      }

      // Quick Actions
      HStack(spacing: DS.Spacing.lg) {
        actionButton(icon: "envelope.fill", label: "Email") { }
        actionButton(icon: "phone.fill", label: "Call") { }
        actionButton(icon: "message.fill", label: "Slack") { }
      }
    }
    // Frame max width removed to satisfy layout contract; relies on StandardScreen column width
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

// MARK: - PropertyRowView

private struct PropertyRowView: View {
  let property: Property

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icons.Entity.property)
        .font(.title2)
        .foregroundColor(DS.Colors.Section.properties)
        .frame(width: 40)

      VStack(alignment: .leading, spacing: 2) {
        Text(property.displayAddress)
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.primary)

        if !property.city.isEmpty {
          Text("\(property.city), \(property.province)")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.Text.secondary)
        }
      }

      Spacer()

      // Listing count badge
      let listingCount = property.activeListings.count
      if listingCount > 0 {
        Text("\(listingCount) listing\(listingCount == 1 ? "" : "s")")
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Section.properties)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(DS.Colors.Section.properties.opacity(0.15))
          .clipShape(Capsule())
      }
    }
    .padding(.vertical, DS.Spacing.sm)
    .contentShape(Rectangle())
  }
}

// MARK: - ListingRowView

private struct ListingRowView: View {
  let listing: Listing

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
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

      Text(listing.status.rawValue.capitalized)
        .font(DS.Typography.caption)
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(DS.Colors.Background.tertiary)
        .clipShape(Capsule())
    }
    .padding(.vertical, DS.Spacing.sm)
    .contentShape(Rectangle())
  }
}

// MARK: - Previews

#Preview("Realtor Profile - Full") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)

      // Add a property owned by Bob
      let property = Property(
        address: "456 Oak Street",
        city: "Toronto",
        province: "ON",
        postalCode: "M5V 1A1",
        ownedBy: PreviewDataFactory.bobID
      )
      context.insert(property)

      // Create a listing on the property owned by Bob
      let listing = Listing(
        address: "456 Oak Street",
        status: .active,
        ownedBy: PreviewDataFactory.bobID
      )
      listing.city = "Toronto"
      listing.province = "ON"
      listing.syncState = .synced
      context.insert(listing)

      // Assign a task to Bob
      let task = TaskItem(
        title: "Update Lockbox Code",
        status: .open,
        declaredBy: PreviewDataFactory.aliceID,
        claimedBy: PreviewDataFactory.bobID,
        listingId: listing.id
      )
      task.syncState = .synced
      context.insert(task)
    }
  ) { context in
    let bobID = PreviewDataFactory.bobID
    let bob = try? context.fetch(
      FetchDescriptor<User>(predicate: #Predicate { $0.id == bobID })
    ).first

    if let bob {
      RealtorProfileView(user: bob)
        .environmentObject(WorkItemActions(
          currentUserId: PreviewDataFactory.aliceID,
          userLookup: { _ in nil }
        ))
    }
  }
}

#Preview("Realtor Profile - Empty") {
  PreviewShell(
    setup: { context in
      // Only seed users, no properties or work items for Bob
      let bob = User(
        id: PreviewDataFactory.bobID,
        name: "Bob Agent",
        email: "bob@dispatch.com",
        avatarHash: nil,
        userType: .realtor
      )
      bob.syncState = .synced
      context.insert(bob)
    }
  ) { context in
    let bobID = PreviewDataFactory.bobID
    let bob = try? context.fetch(
      FetchDescriptor<User>(predicate: #Predicate { $0.id == bobID })
    ).first

    if let bob {
      RealtorProfileView(user: bob)
        .environmentObject(WorkItemActions(
          currentUserId: PreviewDataFactory.aliceID,
          userLookup: { _ in nil }
        ))
    }
  }
}

#Preview("Realtor Profile - Admin User") {
  PreviewShell(
    setup: { context in
      PreviewDataFactory.seed(context)
    }
  ) { context in
    let aliceID = PreviewDataFactory.aliceID
    let alice = try? context.fetch(
      FetchDescriptor<User>(predicate: #Predicate { $0.id == aliceID })
    ).first

    if let alice {
      RealtorProfileView(user: alice)
        .environmentObject(WorkItemActions(
          currentUserId: PreviewDataFactory.aliceID,
          userLookup: { _ in nil }
        ))
    }
  }
}
