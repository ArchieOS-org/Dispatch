//
//  ListingTypePill.swift
//  Dispatch
//
//  Pill component for displaying listing type (Sale, Lease, etc.)
//  Created by Claude on 2025-12-06.
//

import SwiftUI

struct ListingTypePill: View {
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
    
    private var title: String {
        switch type {
        case .sale: return "Sale"
        case .lease: return "Lease"
        case .preListing: return "Pre-List"
        case .rental: return "Rental"
        case .other: return "Other"
        }
    }
    
    private var color: Color {
        switch type {
        case .sale: return DS.Colors.success // Green
        case .lease: return Color.purple // Purple
        case .preListing: return DS.Colors.info // Blue
        case .rental: return DS.Colors.warning // Orange
        case .other: return DS.Colors.Text.tertiary // Gray
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
