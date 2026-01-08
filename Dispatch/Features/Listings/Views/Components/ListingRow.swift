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

  // MARK: Internal

  let listing: Listing
  let owner: User?

  var body: some View {
    HStack(spacing: 6) {
      // Progress ring (same diameter as text height - 17pt for body)
      ProgressCircle(progress: listing.progress, size: 17)

      // Address
      Text(listing.address)
        .font(DS.Typography.body)
        .foregroundColor(DS.Colors.Text.primary)
        .lineLimit(1)

      Spacer()

      // Due date (always shown when exists)
      if let date = listing.dueDate {
        if isOverdue {
          // Overdue: flag + red text
          HStack(spacing: 4) {
            Image(systemName: "flag.fill")
            Text(formattedDate(date))
          }
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Colors.overdue)
        } else {
          // Normal: DatePill style
          DatePill(date: date)
        }
      }
    }
    .padding(.vertical, DS.Spacing.listRowPadding)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: Private

  private var isOverdue: Bool {
    guard let date = listing.dueDate else { return false }
    return date < Calendar.current.startOfDay(for: Date())
  }

  private var statusColor: Color {
    switch listing.status {
    case .draft:
      DS.Colors.Text.tertiary
    case .active:
      DS.Colors.success
    case .pending:
      DS.Colors.warning
    case .closed:
      DS.Colors.info
    case .deleted:
      DS.Colors.Text.disabled
    }
  }

  private var accessibilityLabel: String {
    var parts = [String]()
    parts.append(listing.address)
    if let owner {
      parts.append("Owner: \(owner.name)")
    }
    parts.append("\(listing.tasks.count) tasks")
    parts.append("\(listing.activities.count) activities")
    parts.append("Status: \(listing.status.displayName)")
    return parts.joined(separator: ", ")
  }

  /// Formats a date for display - shows day name if within a week, otherwise month + day
  private func formattedDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let startToday = calendar.startOfDay(for: Date())
    let startDate = calendar.startOfDay(for: date)
    let dayDifference = abs(calendar.dateComponents([.day], from: startDate, to: startToday).day ?? 0)

    let formatter = DateFormatter()
    if dayDifference < 7 {
      formatter.dateFormat = "EEE"
    } else {
      formatter.dateFormat = "MMM d"
    }
    return formatter.string(from: date)
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
        ownedBy: sampleUser.id,
      ),
      owner: sampleUser,
    )

    ListingRow(
      listing: Listing(
        address: "456 Oak Avenue, Unit 12",
        city: "Vancouver",
        province: "BC",
        status: .pending,
        ownedBy: sampleUser.id,
      ),
      owner: sampleUser,
    )

    ListingRow(
      listing: Listing(
        address: "789 Maple Road",
        status: .draft,
        ownedBy: UUID(),
      ),
      owner: nil,
    )
  }
  .listStyle(.plain)
}
