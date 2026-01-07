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
      return true
    case .workItemDetail, .listingDetail:
      return false
    }
  }
}

/// A Things 3-style bottom toolbar for macOS with context-aware actions.
/// Icons only, no labels, with hover states and glass material background.
struct BottomToolbar: View {
  let context: ToolbarContext

  // List context actions
  var audience: Binding<AudienceLens>? = nil
  var onNew: (() -> Void)?
  var onSearch: (() -> Void)?

  // Detail context actions
  var onClaim: (() -> Void)?
  var onDelete: (() -> Void)?

  // Claim state for detail views
  var isClaimable: Bool = true
  var isClaimed: Bool = false

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

  // MARK: - List Toolbar

  @ViewBuilder
  private var listToolbar: some View {
    // Left group
    HStack(spacing: 0) {
        if let audienceBinding = audience {
        AudienceFilterButton(
            lens: audienceBinding.wrappedValue,
            action: {
                withAnimation(.snappy(duration: 0.2)) {
                    audienceBinding.wrappedValue = audienceBinding.wrappedValue.next
                }
            }
        )
        .padding(.trailing, DS.Spacing.md)
        .transition(.opacity)
        .id(audienceBinding.wrappedValue) // Force redraw to fix Toolbar cache issue
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
        action: {},
        accessibilityLabel: "Add subtask"
      )
      .disabled(true)
      .opacity(0.4)

      ToolbarIconButton(
        icon: "calendar",
        action: {},
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
        action: {},
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

  // MARK: - Detail Toolbar

  @ViewBuilder
  private var detailToolbar: some View {
    // Left: Claim button (only for work items, not listings)
    HStack(spacing: 0) {
      if context == .workItemDetail, let onClaim, isClaimable {
        ToolbarIconButton(
          icon: isClaimed ? "hand.raised.slash" : "hand.raised",
          action: onClaim,
          accessibilityLabel: isClaimed ? "Release" : "Claim"
        )
      }
    }
    .padding(.leading, DS.Spacing.bottomToolbarPadding)

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

#Preview("List Context") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .taskList,
      onNew: { print("New") },
      onSearch: { print("Search") }
    )
  }
  .frame(width: 400, height: 200)
}

#Preview("Detail Context") {
  VStack(spacing: 0) {
    Spacer()
    BottomToolbar(
      context: .workItemDetail,
      onClaim: { print("Claim") },
      onDelete: { print("Delete") },
      isClaimable: true,
      isClaimed: false
    )
  }
  .frame(width: 400, height: 200)
}
#endif
