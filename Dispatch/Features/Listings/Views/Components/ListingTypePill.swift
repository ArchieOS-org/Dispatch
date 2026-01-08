//
//  ListingTypePill.swift
//  Dispatch
//
//  Pill component for displaying listing type (Sale, Lease, etc.)
//  Created by Claude on 2025-12-06.
//

import SwiftUI

struct ListingTypePill: View {

  // MARK: Internal

  let type: ListingType

  var body: some View {
    Text(title)
      .font(.system(size: 10, weight: .semibold)) // Tiny, compact font
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.12)) // Subtle tinted background
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  // MARK: Private

  private var title: String {
    switch type {
    case .sale: "Sale"
    case .lease: "Lease"
    case .preListing: "Pre-List"
    case .rental: "Rental"
    case .other: "Other"
    }
  }

  private var color: Color {
    switch type {
    case .sale: DS.Colors.success // Green
    case .lease: Color.purple // Purple
    case .preListing: DS.Colors.info // Blue
    case .rental: DS.Colors.warning // Orange
    case .other: DS.Colors.Text.tertiary // Gray
    }
  }
}

#Preview {
  HStack {
    ListingTypePill(type: .sale)
    ListingTypePill(type: .lease)
    ListingTypePill(type: .preListing)
    ListingTypePill(type: .rental)
    ListingTypePill(type: .other)
  }
  .padding()
}
