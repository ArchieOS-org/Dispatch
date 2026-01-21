# DIS-39: macOS Things 3-Style Collapsible Side Menu

## Overview
Implement a Things 3-style resizable/collapsible sidebar for macOS that replaces the standard NavigationSplitView with a custom layout providing full control over the collapse behavior.

## Core Features (MVP)
- Invisible drag handle that appears on hover at sidebar edge
- Drag to resize between min (200pt) and max (400pt) width
- Drag past minimum to collapse completely
- State persists across app launches via @AppStorage
- Keyboard shortcut ⌘/ to toggle visibility
- Smooth 300ms ease-out animations

## Files to Create

### 1. `Dispatch/Views/Components/macOS/SidebarState.swift`
Observable state manager with @AppStorage persistence:
- `isVisible: Bool` - sidebar visibility
- `width: CGFloat` - current width (clamped 200-400pt)
- `isDragging: Bool` - drag state
- `toggle()` - animated visibility toggle

### 2. `Dispatch/Views/Components/macOS/SidebarDragHandle.swift`
Hover-revealed drag handle:
- Invisible 8pt wide hit area at sidebar edge
- 40pt tall visible handle appears on hover (center of sidebar height)
- `NSCursor.resizeLeftRight` on hover
- DragGesture to resize width
- Collapse when dragged below min width

### 3. `Dispatch/Views/Components/macOS/ResizableSidebar.swift`
Container view using @ViewBuilder for sidebar and content:
- HStack with conditional sidebar + drag handle + content
- .move(edge: .leading) transition for sidebar
- Respects accessibility reduce motion preference

## Files to Modify

### 4. `Dispatch/ContentView.swift` (Lines 175-210)
Replace macOS sidebarNavigation implementation:
```swift
#if os(macOS)
private var sidebarNavigation: some View {
    ResizableSidebar {
        // Sidebar content (existing List)
    } content: {
        // Detail content (existing switch)
    }
}
#endif
```

### 5. `Dispatch/DispatchApp.swift` (Lines 70-80)
Add ⌘/ keyboard shortcut in commands block:
```swift
CommandGroup(after: .sidebar) {
    Button("Toggle Sidebar") {
        NotificationCenter.default.post(name: .toggleSidebar, object: nil)
    }
    .keyboardShortcut("/", modifiers: .command)
}
```

### 6. `Dispatch/Design/Spacing.swift`
Add sidebar constants to DS.Spacing:
```swift
// MARK: - Sidebar (macOS)
static let sidebarMinWidth: CGFloat = 200
static let sidebarMaxWidth: CGFloat = 400
static let sidebarDefaultWidth: CGFloat = 240
static let sidebarDragHandleWidth: CGFloat = 8
static let sidebarDragHandleHeight: CGFloat = 40
```

## Implementation Order

1. [ ] Add sidebar spacing constants to `DS.Spacing`
2. [ ] Create `SidebarState.swift` with persistence
3. [ ] Create `SidebarDragHandle.swift` with hover + drag
4. [ ] Create `ResizableSidebar.swift` container
5. [ ] Update `ContentView.swift` to use ResizableSidebar on macOS
6. [ ] Add ⌘/ keyboard shortcut in `DispatchApp.swift`
7. [ ] Test width persistence across app launches
8. [ ] Polish animations (ensure 300ms ease-out, respect reduce motion)

## Technical Notes

- Use `.onContinuousHover` for cursor changes (macOS-only API)
- Use `@AppStorage` keys: "sidebarVisible", "sidebarWidth"
- Notification: `.toggleSidebar` for keyboard shortcut communication
- Animation: `.easeOut(duration: 0.3)` matches Things 3
- Check `@Environment(\.accessibilityReduceMotion)` for animation preferences

## Phase 2: Smooth Cursor-Following Drag (Current Work)

**Problem**: Current implementation uses `withAnimation` during drag, causing binary snap behavior instead of smooth cursor-following.

**Solution**: Track live width during drag without animation, only animate on drag end.

### Changes to `SidebarState.swift`
Add live drag tracking:
```swift
/// Live width during drag (can go below minWidth for collapse preview)
@Published var liveWidth: CGFloat = 240

/// The effective width to display (liveWidth during drag, width otherwise)
var displayWidth: CGFloat {
  isDragging ? max(0, liveWidth) : width
}

/// Whether to show sidebar based on drag state
var shouldShowSidebar: Bool {
  isDragging ? liveWidth > 0 : isVisible
}
```

Remove `withAnimation` from `show()`/`hide()` methods - animation handled at view level.

### Changes to `SidebarDragHandle.swift`
```swift
.onChanged { value in
  if !state.isDragging {
    dragStartWidth = state.width
    state.isDragging = true
  }
  // Update liveWidth instantly (NO animation during drag)
  state.liveWidth = dragStartWidth + value.translation.width
}
.onEnded { _ in
  // Determine final state
  if state.liveWidth < DS.Spacing.sidebarMinWidth - 30 {
    // Collapse with spring animation
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      state.isVisible = false
    }
  } else {
    // Snap to clamped width with spring
    state.width = state.clampedWidth(state.liveWidth)
  }
  state.isDragging = false
}
```

### Changes to `SidebarEdgeHandle.swift`
When collapsed, dragging from edge should expand sidebar following cursor:
```swift
.onChanged { value in
  if !state.isDragging {
    state.isDragging = true
    state.liveWidth = 0
  }
  // Sidebar grows following cursor (NO animation)
  state.liveWidth = value.translation.width
}
.onEnded { _ in
  if state.liveWidth > 50 {
    // Expand with spring to proper width
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      state.isVisible = true
      state.width = state.clampedWidth(state.liveWidth)
    }
  }
  state.isDragging = false
}
```

### Changes to `ResizableSidebar.swift`
Use `displayWidth` and `shouldShowSidebar` for rendering:
```swift
HStack(spacing: 0) {
  if state.shouldShowSidebar {
    sidebar()
      .frame(width: state.displayWidth)
    SidebarDragHandle(state: state)
  } else if !state.isDragging {
    SidebarEdgeHandle(state: state)
  }
  content()
    .frame(maxWidth: .infinity)
}
// Only animate isVisible changes, NOT during drag
.animation(
  state.isDragging ? .none : (reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)),
  value: state.isVisible
)
```

### Key Principles
1. **During drag**: Update `liveWidth` INSTANTLY with no animation
2. **On drag end**: Use spring animation to settle to final state
3. **Collapse threshold**: ~30pt below minWidth triggers collapse on release
4. **Expand threshold**: ~50pt drag from collapsed edge triggers expand

## Out of Scope (Future)
- ⇧⌘O navigation popover when collapsed
- Trackpad two-finger swipe gestures
- Glass effect for sidebar background (iOS 26+)
