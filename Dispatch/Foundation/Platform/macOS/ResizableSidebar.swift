//
//  ResizableSidebar.swift
//  Dispatch
//
//  Things 3-style resizable sidebar container for macOS
//  Created for DIS-39: Things 3-style collapsible side menu
//

import SwiftUI

#if os(macOS)
/// A container view that provides a Things 3-style resizable sidebar.
/// - Sidebar can be resized by dragging the edge
/// - Sidebar can be collapsed completely
/// - State is per-window (provided via WindowUIState environment)
/// - Responds to keyboard shortcut (Cmd+/)
struct ResizableSidebar<Sidebar: View, Content: View>: View {
  /// Per-window UI state provided via environment
  @Environment(WindowUIState.self) private var windowState

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Ephemeral drag state - view-local, no Combine churn
  @GestureState private var dragDelta: CGFloat = 0
  @State private var dragStartWidth: CGFloat = 0
  @State private var isHovering = false

  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let content: () -> Content

  /// The width used for the sidebar content layout.
  /// Always stays at minWidth or above - never shrinks during collapse.
  private var sidebarContentWidth: CGFloat {
    if windowState.isDragging {
      return windowState.clampedWidthDuringDrag(dragStartWidth + dragDelta)
    }
    return windowState.sidebarWidth
  }

  /// The container width for the sidebar slot.
  /// Changes discretely between sidebarWidth and 0 - NOT animated.
  /// Visual collapse effect is achieved via opacity instead.
  private var containerWidth: CGFloat {
    if windowState.isDragging {
      return windowState.clampedWidthDuringDrag(dragStartWidth + dragDelta)
    }
    return windowState.sidebarVisible ? windowState.sidebarWidth : 0
  }

  /// Whether the sidebar should be visually visible (opacity = 1)
  private var isContentVisible: Bool {
    windowState.sidebarVisible || windowState.isDragging
  }

  var body: some View {
    GeometryReader { _ in
      HStack(spacing: 0) {
        // Sidebar: content layout always uses full width, never shrinks
        // Container uses clipping to hide content when collapsed
        SidebarContainerView(
          sidebarContentWidth: sidebarContentWidth,
          containerWidth: containerWidth,
          isContentVisible: isContentVisible,
          isDragging: windowState.isDragging,
          reduceMotion: reduceMotion
        ) {
          sidebar()
        }

        content()
          .frame(maxWidth: .infinity)
      }
      // Full-height drag handle - always interactive
      .overlay(alignment: .leading) {
        DragHandleView(
          isHovering: $isHovering,
          isDragging: windowState.isDragging,
          reduceMotion: reduceMotion,
          onTap: { toggleSidebar() }
        )
        .offset(x: containerWidth)
        .gesture(dragGesture)
        // Animate drag handle offset smoothly
        .animation(
          windowState.isDragging ? .none : (reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)),
          value: containerWidth
        )
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
      toggleSidebar()
    }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 1)
      .updating($dragDelta) { value, delta, _ in
        delta = value.translation.width.rounded()
      }
      .onChanged { _ in
        // Set isDragging and capture start width ONCE
        if !windowState.isDragging {
          dragStartWidth = windowState.sidebarVisible ? windowState.sidebarWidth : 0
          windowState.isDragging = true
        }
      }
      .onEnded { value in
        let finalWidth = dragStartWidth + value.translation.width

        // Collapse threshold: below minWidth - 30
        if finalWidth < DS.Spacing.sidebarMinWidth - 30 {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            windowState.sidebarVisible = false
          }
        } else {
          // Expand with FULL clamp (min...max) on end only
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            windowState.sidebarVisible = true
            windowState.sidebarWidth = windowState.clampedWidth(finalWidth)
          }
        }

        windowState.isDragging = false
      }
  }

  private func toggleSidebar() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      windowState.toggleSidebar()
    }
  }
}

// MARK: - Sidebar Container View

/// Wraps sidebar content with proper animation isolation.
///
/// The key insight is that we cannot animate frame width through SwiftUI's
/// spring animation because it can overshoot to negative values, causing
/// "Invalid view geometry: width is negative" warnings.
///
/// Solution:
/// 1. Content is laid out at full `sidebarContentWidth` (never shrinks)
/// 2. Container uses `max(0, containerWidth)` to clamp during any interpolation
/// 3. Opacity fades out instantly for visual feedback
/// 4. Handle offset animates for smooth UX (handled in parent)
private struct SidebarContainerView<Content: View>: View {
  let sidebarContentWidth: CGFloat
  let containerWidth: CGFloat
  let isContentVisible: Bool
  let isDragging: Bool
  let reduceMotion: Bool
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .frame(width: sidebarContentWidth)
      .clipped()
      .background {
        Rectangle()
          .fill(.thinMaterial)
          .ignoresSafeArea(.all, edges: .top)
      }
      // Instant opacity change - no spring needed, prevents visual glitches
      .opacity(isContentVisible ? 1 : 0)
      // Use max(0, ...) to clamp any negative values from animation interpolation
      .frame(width: max(0, containerWidth))
      .clipped()
      .allowsHitTesting(isContentVisible)
      // Disable animation on this subtree to prevent frame width interpolation
      .transaction { $0.animation = nil }
  }
}

// MARK: - Drag Handle View

/// A dumb UI component for the drag handle - no gesture logic, no state mutations.
private struct DragHandleView: View {
  @Binding var isHovering: Bool

  let isDragging: Bool
  let reduceMotion: Bool
  let onTap: () -> Void

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: DS.Spacing.sidebarDragHandleWidth)
      .frame(maxHeight: .infinity) // Full height
      .contentShape(Rectangle())
      .overlay(alignment: .center) {
        // Visible handle indicator - shows on hover or during drag
        RoundedRectangle(cornerRadius: DS.Spacing.radiusSmall)
          .fill(Color.primary.opacity(0.3))
          .frame(width: 6, height: DS.Spacing.sidebarDragHandleHeight)
          .opacity(isHovering || isDragging ? 1 : 0)
          .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.15),
            value: isHovering || isDragging
          )
      }
      .onHover { hovering in
        isHovering = hovering
        if hovering {
          NSCursor.resizeLeftRight.push()
        } else {
          NSCursor.pop()
        }
      }
      .onTapGesture(perform: onTap)
  }
}

// MARK: - Preview

#Preview("ResizableSidebar") {
  @Previewable @State var windowState = WindowUIState()

  ResizableSidebar {
    List {
      Label("Tasks", systemImage: "checklist")
      Label("Activities", systemImage: "figure.run")
      Label("Listings", systemImage: "building.2")
    }
    .listStyle(.sidebar)
  } content: {
    Text("Detail Content")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.secondary.opacity(0.1))
  }
  .environment(windowState)
  .frame(width: 800, height: 600)
}
#endif
