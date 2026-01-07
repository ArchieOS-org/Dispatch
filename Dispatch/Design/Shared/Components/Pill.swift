//
//  Pill.swift
//  Dispatch
//
//  Generic pill component for badges and labels.
//  Used by DatePill, OverduePill, and future pill variants.
//

import SwiftUI

struct Pill<Content: View>: View {
  let foregroundColor: Color
  let backgroundColor: Color
  @ViewBuilder let content: () -> Content

  init(
    foreground: Color = DS.Colors.Text.secondary,
    background: Color = DS.Colors.Text.tertiary.opacity(0.15),
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.foregroundColor = foreground
    self.backgroundColor = background
    self.content = content
  }

  var body: some View {
    content()
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}
