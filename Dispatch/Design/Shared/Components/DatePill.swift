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
    Pill {
      Text(dateString)
    }
  }

  private var dateString: String {
    let calendar = Calendar.current
    let startToday = calendar.startOfDay(for: Date())
    let startDate = calendar.startOfDay(for: date)

    // If within 6 days, show Day of Week (e.g., "Mon")
    if let days = calendar.dateComponents([.day], from: startToday, to: startDate).day, days >= 0,
      days < 7
    {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEE"
      return formatter.string(from: date)
    }

    // Otherwise show Date (e.g., "Jan 12")
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
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
