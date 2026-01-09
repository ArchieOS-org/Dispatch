//
//  Pill.swift
//  Dispatch
//
//  Generic pill component for badges and labels.
//  Used by DatePill, OverduePill, and future pill variants.
//

import SwiftUI

struct Pill<Content: View>: View {

  // MARK: Lifecycle

  init(
    foreground: Color = DS.Colors.Text.secondary,
    background: Color = DS.Colors.Text.tertiary.opacity(0.15),
    @ViewBuilder content: @escaping () -> Content
  ) {
    foregroundColor = foreground
    backgroundColor = background
    self.content = content
  }

  // MARK: Internal

  let foregroundColor: Color
  let backgroundColor: Color
  @ViewBuilder let content: () -> Content

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
