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
/// - State persists across app launches
/// - Responds to keyboard shortcut (Cmd+/)
struct ResizableSidebar<Sidebar: View, Content: View>: View {
  @StateObject private var state = SidebarState()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Ephemeral drag state - view-local, no Combine churn
  @GestureState private var dragDelta: CGFloat = 0
  @State private var dragStartWidth: CGFloat = 0
  @State private var isHovering = false

  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let content: () -> Content

  /// Display width: 0...max during drag (no min clamp), 0 or width otherwise
  private var displayWidth: CGFloat {
    if state.isDragging {
      return state.clampedWidthDuringDrag(dragStartWidth + dragDelta)
    }
    return state.isVisible ? state.width : 0
  }

  var body: some View {
    GeometryReader { _ in
      HStack(spacing: 0) {
        // Sidebar ALWAYS mounted - just width=0 when hidden
        sidebar()
          .frame(width: displayWidth)
          .clipped() // Prevent overflow when width=0
          .allowsHitTesting(state.isVisible || state.isDragging)
          .transaction { if state.isDragging { $0.animation = nil } }
          .background {
            // One unified vibrancy layer for everything in the sidebar column
            Rectangle()
              .fill(.thinMaterial)
              .ignoresSafeArea(.all, edges: .top) // fills behind traffic lights
          }

        content()
          .frame(maxWidth: .infinity)
      }
      // Full-height drag handle - always interactive
      .overlay(alignment: .leading) {
        DragHandleView(
          isHovering: $isHovering,
          isDragging: state.isDragging,
          reduceMotion: reduceMotion,
          onTap: { toggleSidebar() }
        )
        .offset(x: displayWidth > 0 ? displayWidth : 0)
        .gesture(dragGesture)
        // NO .allowsHitTesting guard - always interactive
      }
    }
    // Only animate isVisible changes, NOT during drag
    .animation(
      state.isDragging ? .none : (reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)),
      value: state.isVisible
    )
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
        if !state.isDragging {
          dragStartWidth = state.isVisible ? state.width : 0
          state.isDragging = true
        }
      }
      .onEnded { value in
        let finalWidth = dragStartWidth + value.translation.width

        // Collapse threshold: below minWidth - 30
        if finalWidth < DS.Spacing.sidebarMinWidth - 30 {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            state.isVisible = false
          }
        } else {
          // Expand with FULL clamp (min...max) on end only
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            state.isVisible = true
            state.width = state.clampedWidth(finalWidth)
          }
        }

        state.isDragging = false
      }
  }

  private func toggleSidebar() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      state.toggle()
    }
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
        RoundedRectangle(cornerRadius: 3)
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
  .frame(width: 800, height: 600)
}
#endif
