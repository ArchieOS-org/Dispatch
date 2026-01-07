//
//  OverduePill.swift
//  Dispatch
//
//  Overdue badge using canonical Pill component.
//

import SwiftUI

struct OverduePill: View {
  let count: Int

  var body: some View {
    Pill(foreground: .white, background: DS.Colors.overdue) {
      HStack(spacing: 3) {
        Image(systemName: "flag.fill")
          .font(.system(size: 9))
        Text("\(count)")
      }
    }
  }
}

#Preview {
  OverduePill(count: 3)
}
