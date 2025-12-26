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

    // MARK: - Computed Properties

    private var isOverdue: Bool {
        guard let date = listing.dueDate else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    private var overdueText: String {
        guard let date = listing.dueDate else { return "" }
        let startToday = Calendar.current.startOfDay(for: Date())
        let startDue = Calendar.current.startOfDay(for: date)
        let components = Calendar.current.dateComponents([.day], from: startDue, to: startToday)
        let days = components.day ?? 0
        
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    var body: some View {
        HStack(spacing: 6) {
            // Progress Indicator (Left) - Similar position to checkbox
            ProgressCircle(progress: listing.progress, size: 16)

            // Date Pill (Left - Normal)
            if let date = listing.dueDate, !isOverdue {
                DatePill(date: date)
            }

            // Address
            Text(listing.address)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.Text.primary)
                .lineLimit(1)

            Spacer()

            // Metadata (Counts) - Right aligned
            HStack(spacing: DS.Spacing.md) {
                // Overdue Flag (Right)
                if let _ = listing.dueDate, isOverdue {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                        Text(overdueText)
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
                }

                // Task count
                if !listing.tasks.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: DS.Icons.Entity.task)
                            .font(.system(size: 10))
                        Text("\(listing.tasks.count)")
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.Text.tertiary)
                }
                
                // Activity count
                if !listing.activities.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: DS.Icons.Entity.activity)
                            .font(.system(size: 10))
                        Text("\(listing.activities.count)")
                            .font(DS.Typography.caption)
                    }
                    .foregroundColor(DS.Colors.Text.tertiary)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
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
