//
//  BottomToolbar.swift
//  Dispatch
//
//  Things 3-style bottom toolbar for macOS with context-aware actions.
//  Created by Claude on 2025-12-25.
//

#if os(macOS)
import SwiftUI

/// Screen context for bottom toolbar action configuration.
/// The toolbar changes based on the current screen, not selection.
enum ToolbarContext {
  /// List views: TaskListView, ActivityListView, ListingListView, RealtorsListView
  case taskList
  case activityList
  case listingList
  case realtorList

  /// Detail views: WorkItemDetailView, ListingDetailView
  case workItemDetail
  case listingDetail

  /// Whether this context represents a list view
  var isList: Bool {
    switch self {
    case .taskList, .activityList, .listingList, .realtorList:
      true
    case .workItemDetail, .listingDetail:
      false
    }
  }
}

/// A Things 3-style bottom toolbar for macOS with context-aware actions.
/// Icons only, no labels, with hover states and glass material background.
struct BottomToolbar: View {

  // MARK: Internal

  let context: ToolbarContext

  // List context actions
  var audience: Binding<AudienceLens>? = nil
  var onNew: (() -> Void)?
  var onSearch: (() -> Void)?

  /// Detail context actions
  var onDelete: (() -> Void)?

  var body: some View {
    HStack(spacing: 0) {
      if context.isList {
        listToolbar
      } else {
        detailToolbar
      }
    }
    .frame(height: DS.Spacing.bottomToolbarHeight)
    .background {
      Rectangle()
        .fill(.regularMaterial)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
        }
    }
  }

  // MARK: Private

  @ViewBuilder
  private var listToolbar: some View {
    // Left group
    HStack(spacing: 0) {
      if let audienceBinding = audience {
        FilterMenu(audience: audienceBinding)
          .padding(.trailing, DS.Spacing.md)
      }

      if let onNew {
        ToolbarIconButton(
          icon: "plus",
          action: onNew,
          accessibilityLabel: "New item"
        )
      }

      // Placeholder buttons for future features
      ToolbarIconButton(
        icon: "plus.square",
        action: { },
        accessibilityLabel: "Add subtask"
      )
      .disabled(true)
      .opacity(0.4)

      ToolbarIconButton(
        icon: "calendar",
        action: { },
        accessibilityLabel: "Schedule"
      )
      .disabled(true)
      .opacity(0.4)
    }
    .padding(.leading, DS.Spacing.bottomToolbarPadding)

    Spacer()

    // Right group
    HStack(spacing: 0) {
      ToolbarIconButton(
        icon: "arrow.right",
        action: { },
        accessibilityLabel: "Move"
      )
      .disabled(true)
      .opacity(0.4)

      if let onSearch {
        ToolbarIconButton(
          icon: "magnifyingglass",
          action: onSearch,
          accessibilityLabel: "Search"
        )
      }
    }
    .padding(.trailing, DS.Spacing.bottomToolbarPadding)
  }

  @ViewBuilder
  private var detailToolbar: some View {
    // Left spacer for balance
    Spacer()

    // Right: Delete button
    HStack(spacing: 0) {
      if let onDelete {
        ToolbarIconButton(
          icon: "trash",
          action: onDelete,
          accessibilityLabel: "Delete",
          isDestructive: true
        )
      }
    }
    .padding(.trailing, DS.Spacing.bottomToolbarPadding)
  }
}

// MARK: - Previews

// MARK: Interactive

/// Interactive list toolbar with filter cycling
#Preview("Interactive - List") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: 0) {
    // Content area
    VStack {
      Text("Current Filter: \(audience.label)")
        .font(DS.Typography.headline)
      Text("Use the filter menu in the toolbar below")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))

    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 300)
}

/// Interactive detail toolbar
#Preview("Interactive - Detail") {
  VStack(spacing: 0) {
    // Content area
    VStack {
      Text("Work Item Detail")
        .font(DS.Typography.headline)
      Text("Detail toolbar with delete action")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))

    BottomToolbar(
      context: .workItemDetail,
      onDelete: { }
    )
  }
  .frame(width: 500, height: 300)
}

// MARK: List Contexts

/// Task list with all actions
#Preview("Task List - Full") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// Activity list context
#Preview("Activity List") {
  @Previewable @State var audience: AudienceLens = .marketing

  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .activityList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// Listing list context
#Preview("Listing List") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .listingList,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// Realtor list context
#Preview("Realtor List") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .realtorList,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// List without filter (no audience binding)
#Preview("List - No Filter") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// List without new button
#Preview("List - No New Button") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// List without search button
#Preview("List - No Search Button") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { }
    )
  }
  .frame(width: 500, height: 200)
}

// MARK: Detail Contexts

/// Work item detail with delete
#Preview("Work Item Detail") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .workItemDetail,
      onDelete: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// Listing detail - no claim button, only delete
#Preview("Listing Detail") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .listingDetail,
      onDelete: { }
    )
  }
  .frame(width: 500, height: 200)
}

/// Detail without delete button
#Preview("Detail - No Delete") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .workItemDetail
    )
  }
  .frame(width: 500, height: 200)
}

// MARK: Color Schemes

/// Light mode - list context
#Preview("Light Mode - List") {
  @Previewable @State var audience: AudienceLens = .admin

  VStack(spacing: 0) {
    Color(nsColor: .windowBackgroundColor)
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
  .preferredColorScheme(.light)
}

/// Dark mode - list context
#Preview("Dark Mode - List") {
  @Previewable @State var audience: AudienceLens = .admin

  VStack(spacing: 0) {
    Color(nsColor: .windowBackgroundColor)
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 500, height: 200)
  .preferredColorScheme(.dark)
}

/// Light mode - detail context
#Preview("Light Mode - Detail") {
  VStack(spacing: 0) {
    Color(nsColor: .windowBackgroundColor)
    BottomToolbar(
      context: .workItemDetail,
      onDelete: { }
    )
  }
  .frame(width: 500, height: 200)
  .preferredColorScheme(.light)
}

/// Dark mode - detail context
#Preview("Dark Mode - Detail") {
  VStack(spacing: 0) {
    Color(nsColor: .windowBackgroundColor)
    BottomToolbar(
      context: .workItemDetail,
      onDelete: { }
    )
  }
  .frame(width: 500, height: 200)
  .preferredColorScheme(.dark)
}

// MARK: Width Variations

/// Narrow window
#Preview("Narrow Width") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 300, height: 200)
}

/// Wide window
#Preview("Wide Width") {
  @Previewable @State var audience: AudienceLens = .all

  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      audience: $audience,
      onNew: { },
      onSearch: { }
    )
  }
  .frame(width: 800, height: 200)
}

// MARK: All Filter States Gallery

/// Shows toolbar with each audience filter state
#Preview("Filter States Gallery") {
  VStack(spacing: DS.Spacing.lg) {
    ForEach(AudienceLens.allCases, id: \.self) { lens in
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(lens.label)
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, DS.Spacing.md)

        BottomToolbar(
          context: .taskList,
          audience: .constant(lens),
          onNew: { },
          onSearch: { }
        )
      }
    }
  }
  .padding(.vertical, DS.Spacing.md)
  .frame(width: 500)
  .background(Color(nsColor: .windowBackgroundColor))
}

#endif
