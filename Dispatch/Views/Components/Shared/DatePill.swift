//
//  DatePill.swift
//  Dispatch
//
//  Things 3 style date pill for list rows
//  Created by Claude on 2025-12-06.
//

import SwiftUI

struct DatePill: View {
    let date: Date
    
    var body: some View {
        Text(dateString)
            .font(.system(size: 11, weight: .semibold)) // Small, compact font
            .foregroundStyle(DS.Colors.Text.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DS.Colors.Text.tertiary.opacity(0.15)) // Light gray background
            .clipShape(RoundedRectangle(cornerRadius: 4)) // Subtle rounding
    }
    
    private var dateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tom"
        } else {
            // Check if within next 7 days
            if let days = calendar.dateComponents([.day], from: Date(), to: date).day, days < 7, days > 0 {
                let formatter = DateFormatter()
                formatter.dateFormat = "E" // "Tue", "Wed"
                return formatter.string(from: date)
            } else {
                // "Jan 9" format
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        DatePill(date: Date())
        DatePill(date: Date().addingTimeInterval(86400))
        DatePill(date: Date().addingTimeInterval(86400 * 3))
        DatePill(date: Date().addingTimeInterval(86400 * 10))
    }
}
