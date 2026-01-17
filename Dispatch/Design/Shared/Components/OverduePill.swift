//
//  OverduePill.swift
//  Dispatch
//
//  Overdue badge using canonical Pill component.
//

import SwiftUI

struct OverduePill: View {
  let count: Int

  @ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 9

  var body: some View {
    Pill(foreground: .white, background: DS.Colors.overdue) {
      HStack(spacing: 3) {
        Image(systemName: "flag.fill")
          .font(.system(size: iconSize))
        Text("\(count)")
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: - Accessibility

  var accessibilityLabel: String {
    count == 1 ? "1 overdue task" : "\(count) overdue tasks"
  }
}

#Preview {
  OverduePill(count: 3)
}
