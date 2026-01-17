//
//  CollapsibleHeader.swift
//  Dispatch
//
//  Shared Component - Scroll-aware collapsing header
//  Created by Claude on 2025-12-06.
//

import SwiftUI

// MARK: - ScrollOffsetKey

/// PreferenceKey for tracking scroll offset
struct ScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: - Linear Interpolation Helper

/// Linear interpolation between two values based on progress (0-1)
private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
  start + (end - start) * progress
}

// MARK: - CollapsibleHeader

/// A scroll-aware header that collapses as the user scrolls.
/// Title font interpolates from 32pt → 18pt as collapse progresses.
struct CollapsibleHeader<Content: View>: View {

  // MARK: Lifecycle

  init(
    title: String,
    scrollOffset: CGFloat,
    expandedHeight: CGFloat = 100,
    collapsedHeight: CGFloat = 56,
    maxOffset: CGFloat = 80,
    @ViewBuilder trailingContent: @escaping () -> Content = { EmptyView() }
  ) {
    self.title = title
    self.scrollOffset = scrollOffset
    self.expandedHeight = expandedHeight
    self.collapsedHeight = collapsedHeight
    self.maxOffset = maxOffset
    self.trailingContent = trailingContent
  }

  // MARK: Internal

  let title: String
  let scrollOffset: CGFloat
  let expandedHeight: CGFloat
  let collapsedHeight: CGFloat
  let maxOffset: CGFloat
  @ViewBuilder let trailingContent: () -> Content

  var body: some View {
    HStack(alignment: .bottom) {
      Text(title)
        .font(.system(size: titleFontSize, weight: .bold))
        .foregroundColor(DS.Colors.Text.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Spacer()

      trailingContent()
        .opacity(secondaryOpacity)
    }
    .frame(height: headerHeight)
    #if os(macOS)
      .padding(.horizontal, DS.Spacing.Layout.pageMargin)
      .padding(.top, DS.Spacing.Layout.topHeaderPadding - 20) // Adjust for collapsible nature
    #else
      .padding(.horizontal, DS.Spacing.md)
    #endif
      .background(DS.Colors.Background.primary)
  }

  // MARK: Private

  /// Progress of collapse animation (0 = expanded, 1 = collapsed)
  private var collapseProgress: CGFloat {
    min(1, max(0, scrollOffset / maxOffset))
  }

  /// Interpolated title font size
  private var titleFontSize: CGFloat {
    lerp(32, 18, collapseProgress)
  }

  /// Interpolated header height
  private var headerHeight: CGFloat {
    lerp(expandedHeight, collapsedHeight, collapseProgress)
  }

  /// Interpolated opacity for secondary elements
  private var secondaryOpacity: CGFloat {
    1 - collapseProgress
  }

}

// MARK: - CollapsibleHeaderScrollView

/// A container view that wraps scrollable content with a collapsible header.
/// Automatically tracks scroll position and passes it to the header.
struct CollapsibleHeaderScrollView<Header: View, Content: View>: View {

  // MARK: Internal

  @ViewBuilder let header: (CGFloat) -> Header
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      header(scrollOffset)

      ScrollView {
        // Scroll position tracker
        GeometryReader { geometry in
          Color.clear
            .preference(
              key: ScrollOffsetKey.self,
              value: -geometry.frame(in: .named("scroll")).origin.y
            )
        }
        .frame(height: 0)

        content()
      }
      .coordinateSpace(name: "scroll")
      .onPreferenceChange(ScrollOffsetKey.self) { value in
        scrollOffset = value
      }
      .pullToSearch()
    }
  }

  // MARK: Private

  @State private var scrollOffset: CGFloat = 0

}

// MARK: - Preview

#Preview("Collapsible Header") {
  CollapsibleHeaderScrollView { offset in
    CollapsibleHeader(
      title: "Work Item Title",
      scrollOffset: offset
    ) {
      Circle()
        .fill(DS.Colors.PriorityColors.high)
        .frame(width: DS.Spacing.priorityDotSize, height: DS.Spacing.priorityDotSize)
    }
  } content: {
    VStack(spacing: DS.Spacing.md) {
      ForEach(0 ..< 20, id: \.self) { index in
        Text("Content row \(index + 1)")
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
          .background(DS.Colors.Background.card)
          .cornerRadius(DS.Spacing.radiusCard)
      }
    }
    .padding()
  }
}
