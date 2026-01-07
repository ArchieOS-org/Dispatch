//
//  PriorityDot.swift
//  Dispatch
//
//  Shared Component - Color-coded priority indicator dot
//  Created by Claude on 2025-12-06.
//

import SwiftUI

/// A small colored dot indicating the priority level of a work item.
/// Uses design system tokens for consistent sizing and coloring.
struct PriorityDot: View {
  let priority: Priority

  var body: some View {
    Circle()
      .fill(DS.Colors.PriorityColors.color(for: priority))
      .frame(width: DS.Spacing.priorityDotSize, height: DS.Spacing.priorityDotSize)
      .accessibilityLabel("\(priority.rawValue) priority")
  }
}

// MARK: - Preview

#Preview("All Priorities") {
  HStack(spacing: DS.Spacing.md) {
    ForEach(Priority.allCases, id: \.self) { priority in
      VStack(spacing: DS.Spacing.xs) {
        PriorityDot(priority: priority)
        Text(priority.rawValue.capitalized)
          .font(DS.Typography.caption)
      }
    }
  }
  .padding()
}
