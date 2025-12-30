//
//  RealtorsListView.swift
//  Dispatch
//
//  Created by Claude on 2025-12-28.
//  Refactored for Layout Unification (StandardScreen)
//

import SwiftUI
import SwiftData

/// Displays a list of realtors in the organization.
struct RealtorsListView: View {


    // MARK: - Queries

    @Query(sort: \User.name) private var allUsers: [User]

    private var activeRealtorList: [User] {
        allUsers.filter { $0.userType == .realtor }
    }
    
    // MARK: - Environment

    @EnvironmentObject private var lensState: LensState

    // MARK: - State

    @State private var showAddSheet = false
    
    // MARK: - Body

    var body: some View {
        content
            .sheet(isPresented: $showAddSheet) {
                EditRealtorSheet()
            }
    }

    private var content: some View {
        StandardScreen(title: "Realtors", layout: .column, scroll: .disabled) {
            StandardList(activeRealtorList) { user in
                NavigationLink(value: user) {
                    RealtorRow(user: user)
                }
                .buttonStyle(.plain)
            }
        } toolbarContent: {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            // No-op or remove if not needed, but fixing structure first. 
            // Phase 2 goal was to remove onAppear, so let's just close content.
        }
    }
}

// MARK: - Realtor Row Component

/// A row displaying a realtor's avatar, name, and listing count.
private struct RealtorRow: View {
    let user: User

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Avatar Placeholder
            Circle()
                .fill(DS.Colors.Background.secondary)
                .frame(width: 40, height: 40)
                .overlay {
                    if let avatarData = user.avatar, let pImage = PlatformImage.from(data: avatarData) {
                        Image(platformImage: pImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                    } else {
                        Text(user.initials)
                            .font(DS.Typography.bodySecondary)
                            .foregroundStyle(DS.Colors.Text.secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.Text.primary)

                Text("\(user.listings.count) active listings")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.Text.secondary)
            }

            Spacer()

            Image(systemName: DS.Icons.Navigation.forward)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.Text.tertiary)
        }
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: User.self, Listing.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext
    let user = User(
        name: "Sarah Connors",
        email: "sarah@dispatch.ca",
        userType: .realtor
    )
    context.insert(user)
    
    let listing = Listing(address: "123 Main St", city: "Toronto", province: "ON", postalCode: "M5V 2H1", ownedBy: user.id)
    context.insert(listing)

    return RealtorsListView()
        .modelContainer(container)
        .environmentObject(LensState())
}

extension User {
    var initials: String {
        let components = name.components(separatedBy: " ")
        if let first = components.first?.first, let last = components.last?.first {
            return "\(first)\(last)"
        }
        return String(name.prefix(2))
    }
}
