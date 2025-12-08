//
//  ListingRow.swift
//  Dispatch
//
//  Row component for displaying listings in a list
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A list row displaying a listing with:
/// - Address as headline
/// - Owner name, task count, activity count, and status badge
struct ListingRow: View {
    let listing: Listing
    let owner: User?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Address
            Text(listing.address)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.Text.primary)
                .lineLimit(1)

            // Metadata row
            HStack(spacing: DS.Spacing.md) {
                // Owner name
                if let owner = owner {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: DS.Icons.Entity.user)
                            .font(.system(size: 10))
                        Text(owner.name)
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.Text.secondary)
                }

                Spacer()

                // Task count badge
                HStack(spacing: 2) {
                    Image(systemName: DS.Icons.Entity.task)
                        .font(.system(size: 10))
                    Text("\(listing.tasks.count)")
                        .font(DS.Typography.caption)
                }
                .foregroundColor(DS.Colors.Text.tertiary)

                // Activity count badge
                HStack(spacing: 2) {
                    Image(systemName: DS.Icons.Entity.activity)
                        .font(.system(size: 10))
                    Text("\(listing.activities.count)")
                        .font(DS.Typography.caption)
                }
                .foregroundColor(DS.Colors.Text.tertiary)

                // Status badge
                Text(listing.status.displayName)
                    .font(DS.Typography.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch listing.status {
        case .draft:
            return DS.Colors.Text.tertiary
        case .active:
            return DS.Colors.success
        case .pending:
            return DS.Colors.warning
        case .closed:
            return DS.Colors.info
        case .deleted:
            return DS.Colors.Text.disabled
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        parts.append(listing.address)
        if let owner = owner {
            parts.append("Owner: \(owner.name)")
        }
        parts.append("\(listing.tasks.count) tasks")
        parts.append("\(listing.activities.count) activities")
        parts.append("Status: \(listing.status.displayName)")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Listing Row") {
    let sampleUser = User(name: "Jane Realtor", email: "jane@example.com", userType: .realtor)

    List {
        ListingRow(
            listing: Listing(
                address: "123 Main Street",
                city: "Toronto",
                province: "ON",
                postalCode: "M5V 1A1",
                price: 899000,
                status: .active,
                ownedBy: sampleUser.id
            ),
            owner: sampleUser
        )

        ListingRow(
            listing: Listing(
                address: "456 Oak Avenue, Unit 12",
                city: "Vancouver",
                province: "BC",
                status: .pending,
                ownedBy: sampleUser.id
            ),
            owner: sampleUser
        )

        ListingRow(
            listing: Listing(
                address: "789 Maple Road",
                status: .draft,
                ownedBy: UUID()
            ),
            owner: nil
        )
    }
    .listStyle(.plain)
}
