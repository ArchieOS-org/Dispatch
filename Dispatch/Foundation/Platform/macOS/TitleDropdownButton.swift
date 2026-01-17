#if os(macOS)
import SwiftUI

/// A clickable title with chevron that triggers the navigation popover.
/// Mimics the Things 3 "Slim Mode" title button.
/// Note: Currently unused as of Dec 2025 (Search moved to global modal).
struct TitleDropdownButton: View {
  let title: String
  @Binding var isHovering: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Text(title)
          .font(DS.Typography.headline)
          .foregroundColor(.primary)

        Image(systemName: "chevron.down")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
          .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovering = hovering
    }
  }
}

// MARK: - Previews

// MARK: Interactive

/// Interactive preview - hover to see background change
#Preview("Interactive") {
  @Previewable @State var isHovering = false

  VStack(spacing: DS.Spacing.lg) {
    Text("Hover over the button")
      .font(DS.Typography.caption)
      .foregroundStyle(.secondary)

    TitleDropdownButton(
      title: "Inbox",
      isHovering: $isHovering
    ) { }

    Text(isHovering ? "Hovering" : "Not hovering")
      .font(DS.Typography.captionSecondary)
      .foregroundStyle(.tertiary)
  }
  .padding(DS.Spacing.xl)
}

// MARK: States

/// Default state - not hovering
#Preview("Default State") {
  TitleDropdownButton(
    title: "Inbox",
    isHovering: .constant(false)
  ) { }
    .padding(DS.Spacing.xl)
}

/// Hover state - shows subtle background
#Preview("Hover State") {
  TitleDropdownButton(
    title: "Inbox",
    isHovering: .constant(true)
  ) { }
    .padding(DS.Spacing.xl)
}

// MARK: Title Lengths

/// Short title
#Preview("Short Title") {
  HStack(spacing: DS.Spacing.lg) {
    TitleDropdownButton(title: "All", isHovering: .constant(false)) { }
    TitleDropdownButton(title: "All", isHovering: .constant(true)) { }
  }
  .padding(DS.Spacing.xl)
}

/// Medium title
#Preview("Medium Title") {
  HStack(spacing: DS.Spacing.lg) {
    TitleDropdownButton(title: "Inbox", isHovering: .constant(false)) { }
    TitleDropdownButton(title: "Inbox", isHovering: .constant(true)) { }
  }
  .padding(DS.Spacing.xl)
}

/// Long title
#Preview("Long Title") {
  HStack(spacing: DS.Spacing.lg) {
    TitleDropdownButton(title: "Marketing Campaign", isHovering: .constant(false)) { }
    TitleDropdownButton(title: "Marketing Campaign", isHovering: .constant(true)) { }
  }
  .padding(DS.Spacing.xl)
}

// MARK: Color Schemes

/// Light mode appearance
#Preview("Light Mode") {
  HStack(spacing: DS.Spacing.lg) {
    TitleDropdownButton(title: "Inbox", isHovering: .constant(false)) { }
    TitleDropdownButton(title: "Inbox", isHovering: .constant(true)) { }
  }
  .padding(DS.Spacing.xl)
  .preferredColorScheme(.light)
}

/// Dark mode appearance
#Preview("Dark Mode") {
  HStack(spacing: DS.Spacing.lg) {
    TitleDropdownButton(title: "Inbox", isHovering: .constant(false)) { }
    TitleDropdownButton(title: "Inbox", isHovering: .constant(true)) { }
  }
  .padding(DS.Spacing.xl)
  .preferredColorScheme(.dark)
}

// MARK: Toolbar Context

/// Shows button in a toolbar-like context
#Preview("Toolbar Context") {
  @Previewable @State var isHovering = false

  VStack(spacing: 0) {
    // Simulated toolbar
    HStack {
      TitleDropdownButton(
        title: "Inbox",
        isHovering: $isHovering
      ) { }

      Spacer()

      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.sm)
    .background(.bar)

    Divider()

    // Content area
    Color(nsColor: .windowBackgroundColor)
      .frame(height: 200)
  }
  .frame(width: 300)
}

// MARK: All States Gallery

/// Side-by-side comparison of all states
#Preview("All States Gallery") {
  VStack(alignment: .leading, spacing: DS.Spacing.lg) {
    HStack(spacing: DS.Spacing.xl) {
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Default")
          .font(DS.Typography.captionSecondary)
          .foregroundStyle(.tertiary)
        TitleDropdownButton(title: "Inbox", isHovering: .constant(false)) { }
      }

      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text("Hover")
          .font(DS.Typography.captionSecondary)
          .foregroundStyle(.tertiary)
        TitleDropdownButton(title: "Inbox", isHovering: .constant(true)) { }
      }
    }
  }
  .padding(DS.Spacing.xl)
}

#endif
