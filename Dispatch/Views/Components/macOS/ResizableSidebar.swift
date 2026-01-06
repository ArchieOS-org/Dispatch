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

  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let content: () -> Content

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        // Sidebar content - always in hierarchy when visible or dragging
        if state.shouldShowSidebar {
          sidebar()
            .frame(width: state.displayWidth)
            .clipped()
        }

        content()
          .frame(maxWidth: .infinity)
      }
      // Unified drag handle overlay - persists through entire drag
      .overlay(alignment: .leading) {
        UnifiedDragHandle(state: state, reduceMotion: reduceMotion)
          .offset(x: state.shouldShowSidebar ? state.displayWidth - DS.Spacing.sidebarDragHandleWidth / 2 : 0)
      }
    }
    // Only animate isVisible changes, NOT during drag
    .animation(
      state.isDragging ? .none : (reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)),
      value: state.isVisible
    )
    .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        state.toggle()
      }
    }
  }
}

// MARK: - Unified Drag Handle

/// A persistent drag handle that works in both collapsed and expanded states.
/// This overlay persists through the entire drag operation, preventing gesture cancellation.
private struct UnifiedDragHandle: View {
  @ObservedObject var state: SidebarState
  let reduceMotion: Bool

  @State private var isHovering: Bool = false
  @State private var dragStartWidth: CGFloat = 0

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: DS.Spacing.sidebarDragHandleWidth)
      .contentShape(Rectangle())
      .overlay(alignment: .center) {
        // Visible handle indicator - shows on hover or during drag
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.primary.opacity(0.3))
          .frame(width: 4, height: DS.Spacing.sidebarDragHandleHeight)
          .opacity(isHovering || state.isDragging ? 1 : 0)
          .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.15),
            value: isHovering || state.isDragging
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
      .gesture(dragGesture)
      .onTapGesture {
        // Toggle sidebar on tap
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          state.toggle()
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 1)
      .onChanged { value in
        if !state.isDragging {
          // Capture starting state
          dragStartWidth = state.isVisible ? state.width : 0
          state.isDragging = true
        }

        // Update liveWidth instantly - sidebar follows cursor
        state.liveWidth = dragStartWidth + value.translation.width
      }
      .onEnded { _ in
        // Determine final state based on final width
        let finalWidth = state.liveWidth

        if finalWidth < DS.Spacing.sidebarMinWidth - 30 {
          // Collapse
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            state.isVisible = false
          }
        } else if finalWidth > 50 || state.isVisible {
          // Expand or stay visible with proper width
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            state.isVisible = true
            state.width = state.clampedWidth(finalWidth)
            state.liveWidth = state.width
          }
        }

        state.isDragging = false
      }
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
