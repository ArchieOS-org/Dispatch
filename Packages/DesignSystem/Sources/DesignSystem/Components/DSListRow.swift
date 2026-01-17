//
//  DSListRow.swift
//  DesignSystem
//
//  Standard list row shell with consistent layout and spacing.
//  Domain-agnostic foundation for specialized list rows.
//

import SwiftUI

/// A standard list row container with consistent layout and spacing.
/// Provides leading, content, and trailing slots with proper alignment.
///
/// Usage:
/// ```swift
/// DSListRow {
///   Text("Main content")
/// }
///
/// DSListRow(
///   leading: { Image(systemName: "star") },
///   trailing: { Text("123") }
/// ) {
///   Text("Content with leading/trailing")
/// }
/// ```
public struct DSListRow<Leading: View, Content: View, Trailing: View>: View {

  // MARK: Lifecycle

  /// Creates a list row with optional leading and trailing content.
  /// - Parameters:
  ///   - verticalPadding: Vertical padding. Defaults to list row padding.
  ///   - horizontalPadding: Horizontal padding. Defaults to medium spacing.
  ///   - spacing: Spacing between elements. Defaults to small spacing.
  ///   - alignment: Vertical alignment. Defaults to center.
  ///   - leading: Leading content (icon, avatar, checkbox).
  ///   - trailing: Trailing content (count, chevron, action).
  ///   - content: Main row content.
  public init(
    verticalPadding: CGFloat = DS.Spacing.listRowPadding,
    horizontalPadding: CGFloat = DS.Spacing.md,
    spacing: CGFloat = DS.Spacing.sm,
    alignment: VerticalAlignment = .center,
    @ViewBuilder leading: () -> Leading,
    @ViewBuilder trailing: () -> Trailing,
    @ViewBuilder content: () -> Content
  ) {
    self.verticalPadding = verticalPadding
    self.horizontalPadding = horizontalPadding
    self.spacing = spacing
    self.alignment = alignment
    self.leading = leading()
    self.trailing = trailing()
    self.content = content()
  }

  // MARK: Public

  public var body: some View {
    HStack(alignment: alignment, spacing: spacing) {
      leading
      content
      Spacer(minLength: 0)
      trailing
    }
    .padding(.vertical, verticalPadding)
    .padding(.horizontal, horizontalPadding)
    .contentShape(Rectangle()) // Ensure full row is tappable
  }

  // MARK: Internal

  let verticalPadding: CGFloat
  let horizontalPadding: CGFloat
  let spacing: CGFloat
  let alignment: VerticalAlignment
  let leading: Leading
  let trailing: Trailing
  let content: Content

}

// MARK: - Convenience Initializers

extension DSListRow where Leading == EmptyView, Trailing == EmptyView {
  /// Creates a simple list row with only main content.
  public init(
    verticalPadding: CGFloat = DS.Spacing.listRowPadding,
    horizontalPadding: CGFloat = DS.Spacing.md,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      verticalPadding: verticalPadding,
      horizontalPadding: horizontalPadding,
      leading: { EmptyView() },
      trailing: { EmptyView() },
      content: content
    )
  }
}

extension DSListRow where Leading == EmptyView {
  /// Creates a list row with content and trailing element.
  public init(
    verticalPadding: CGFloat = DS.Spacing.listRowPadding,
    horizontalPadding: CGFloat = DS.Spacing.md,
    spacing: CGFloat = DS.Spacing.sm,
    alignment: VerticalAlignment = .center,
    @ViewBuilder trailing: () -> Trailing,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      verticalPadding: verticalPadding,
      horizontalPadding: horizontalPadding,
      spacing: spacing,
      alignment: alignment,
      leading: { EmptyView() },
      trailing: trailing,
      content: content
    )
  }
}

extension DSListRow where Trailing == EmptyView {
  /// Creates a list row with leading element and content.
  public init(
    verticalPadding: CGFloat = DS.Spacing.listRowPadding,
    horizontalPadding: CGFloat = DS.Spacing.md,
    spacing: CGFloat = DS.Spacing.sm,
    alignment: VerticalAlignment = .center,
    @ViewBuilder leading: () -> Leading,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      verticalPadding: verticalPadding,
      horizontalPadding: horizontalPadding,
      spacing: spacing,
      alignment: alignment,
      leading: leading,
      trailing: { EmptyView() },
      content: content
    )
  }
}

// MARK: - Preview

#Preview("DSListRow - Simple") {
  VStack(spacing: 0) {
    DSListRow {
      Text("Simple row")
    }
    DSDivider()
    DSListRow {
      Text("Another row")
    }
    DSDivider()
    DSListRow {
      VStack(alignment: .leading, spacing: 2) {
        Text("Title").font(DS.Typography.headline)
        Text("Subtitle").font(DS.Typography.caption).foregroundStyle(.secondary)
      }
    }
  }
  .background(DS.Colors.Background.primary)
}

#Preview("DSListRow - With Leading") {
  VStack(spacing: 0) {
    DSListRow(leading: {
      Image(systemName: "star.fill")
        .foregroundStyle(.yellow)
    }) {
      Text("Favorites")
    }
    DSDivider()
    DSListRow(leading: {
      Image(systemName: "folder.fill")
        .foregroundStyle(.blue)
    }) {
      Text("Documents")
    }
    DSDivider()
    DSListRow(leading: {
      DSCheckbox(isChecked: true)
    }) {
      Text("Completed item")
    }
  }
  .background(DS.Colors.Background.primary)
}

#Preview("DSListRow - With Trailing") {
  VStack(spacing: 0) {
    DSListRow(trailing: {
      Text("123")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
    }) {
      Text("Count")
    }
    DSDivider()
    DSListRow(trailing: {
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }) {
      Text("Navigate")
    }
    DSDivider()
    DSListRow(trailing: {
      DSPill { Text("New") }
    }) {
      Text("With badge")
    }
  }
  .background(DS.Colors.Background.primary)
}

#Preview("DSListRow - Full") {
  VStack(spacing: 0) {
    DSListRow(
      leading: {
        Circle()
          .fill(.blue)
          .frame(width: 32, height: 32)
          .overlay(
            Text("JD")
              .font(DS.Typography.caption)
              .foregroundStyle(.white)
          )
      },
      trailing: {
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    ) {
      VStack(alignment: .leading, spacing: 2) {
        Text("John Doe").font(DS.Typography.headline)
        Text("johndoe@example.com").font(DS.Typography.caption).foregroundStyle(.secondary)
      }
    }
    DSDivider()
    DSListRow(
      alignment: .top,
      leading: {
        DSProgressCircle(progress: 0.7, size: 20)
      },
      trailing: {
        VStack(alignment: .trailing, spacing: 2) {
          Text("75%").font(DS.Typography.caption)
          Text("In Progress").font(DS.Typography.captionSecondary).foregroundStyle(.secondary)
        }
      }
    ) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Project Alpha").font(DS.Typography.headline)
        Text("Due in 3 days").font(DS.Typography.caption).foregroundStyle(.secondary)
      }
    }
  }
  .background(DS.Colors.Background.primary)
}
