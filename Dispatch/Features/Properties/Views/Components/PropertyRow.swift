//
//  PropertyRow.swift
//  Dispatch
//
//  Row component for displaying properties in a list
//

import SwiftUI

/// A list row displaying a property with:
/// - Address as headline (with optional unit)
/// - City/province, property type pill, and listing count badge
struct PropertyRow: View {

  // MARK: Internal

  let property: Property
  let owner: User?

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      // Address info
      VStack(alignment: .leading, spacing: 2) {
        Text(property.displayAddress)
          .font(DS.Typography.body)
          .foregroundColor(DS.Colors.Text.primary)
          .lineLimit(1)

        if !property.city.isEmpty || !property.province.isEmpty {
          Text(locationText)
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.Text.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      // Metadata (Right aligned)
      HStack(spacing: DS.Spacing.md) {
        // Listing count
        if !property.activeListings.isEmpty {
          HStack(spacing: 2) {
            Image(systemName: DS.Icons.Entity.listing)
              .font(.system(size: listingIconSize))
            Text("\(property.activeListings.count)")
              .font(DS.Typography.caption)
          }
          .foregroundColor(DS.Colors.Text.tertiary)
        }

        // Property type pill
        Text(property.propertyType.displayName)
          .font(DS.Typography.caption)
          .foregroundColor(DS.Colors.Section.properties)
          .padding(.horizontal, DS.Spacing.sm)
          .padding(.vertical, 2)
          .background(DS.Colors.Section.properties.opacity(0.15))
          .clipShape(Capsule())
      }
    }
    .padding(.vertical, DS.Spacing.listRowPadding)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(property.displayAddress)
  }

  // MARK: Private

  /// Scaled listing icon size for Dynamic Type support (base: 10pt)
  @ScaledMetric(relativeTo: .caption2)
  private var listingIconSize: CGFloat = 10

  private var locationText: String {
    [property.city, property.province]
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

  private var accessibilityLabel: String {
    var parts = [String]()
    parts.append(property.displayAddress)
    if !property.city.isEmpty {
      parts.append(property.city)
    }
    parts.append("\(property.activeListings.count) listings")
    parts.append("Type: \(property.propertyType.displayName)")
    return parts.joined(separator: ", ")
  }
}

// MARK: - Preview

#Preview("Property Row") {
  let sampleUser = User(name: "Jane Realtor", email: "jane@example.com", userType: .realtor)

  List {
    PropertyRow(
      property: Property(
        address: "123 Main Street",
        city: "Toronto",
        province: "ON",
        postalCode: "M5V 1A1",
        propertyType: .residential,
        ownedBy: sampleUser.id
      ),
      owner: sampleUser
    )

    PropertyRow(
      property: Property(
        address: "456 Oak Avenue",
        unit: "12",
        city: "Vancouver",
        province: "BC",
        propertyType: .condo,
        ownedBy: sampleUser.id
      ),
      owner: sampleUser
    )

    PropertyRow(
      property: Property(
        address: "789 Industrial Blvd",
        city: "Calgary",
        province: "AB",
        propertyType: .commercial,
        ownedBy: UUID()
      ),
      owner: nil
    )
  }
  .listStyle(.plain)
}
