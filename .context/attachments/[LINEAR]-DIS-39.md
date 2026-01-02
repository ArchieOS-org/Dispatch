# DIS-39: macOS: Add Things 3 style collapsible side menu

**Linear URL:** https://linear.app/archieos/issue/DIS-39/macos-add-things-3-style-collapsible-side-menu

**Status:** Todo
**Priority:** No priority
**Labels:** UX, macOS

## Description

Implement a collapsible side menu like the Things 3 app:

* There's an invisible bar in the middle of the right side of the menu that appears when you hover near it
* You can slide the menu open and close
* It can expand to big or collapse to small/hidden
* The menu stays in its state and you can expand it later

---

## Things 3 Sidebar Patterns (Research Summary)

### Core Design Philosophy

Things 3's sidebar is a masterclass in reducing distraction while maintaining power. The key insight: **hide what you don't need, but make it instantly accessible**. The sidebar is a transient tool, not a permanent fixture.

### Key Patterns

#### 1\. Slim Mode (Fully Collapsed)

* Sidebar can be **completely hidden** ("Slim Mode")
* When hidden, the main content takes the full window width
* Described as "focus mode" - cuts distractions for deep work
* Perfect for split view or limited screen space

#### 2\. Drag Handle Behavior

* **Invisible until hover**: The drag handle only appears when the mouse hovers near the sidebar/content boundary
* Handle appears at the **center-right edge** of the sidebar (not the full height)
* **Cursor changes** to resize cursor (`ew-resize`) on hover
* Provides **haptic/visual feedback** during drag

#### 3\. Interaction Methods (Multiple Entry Points)

Things 3 supports **three ways** to toggle the sidebar:

| Method | Action |
| -- | -- |
| **Mouse drag** | Hover at sidebar edge → grab handle → drag left to hide, right to show |
| **Keyboard shortcut** | `⌘/` (Cmd + /) toggles sidebar visibility |
| **Trackpad gesture** | Two-finger swipe left/right |

#### 4\. State Persistence

* Sidebar state (expanded/collapsed) **persists across app launches**
* Width preference is remembered
* Uses `@AppStorage` or equivalent for persistence

#### 5\. Animation & Feel

* Smooth `ease-out` animation when collapsing/expanding
* \~300ms duration for state transitions
* Content area animates to fill available space
* No jarring jumps or layout thrashing

#### 6\. Navigation While Collapsed

When sidebar is hidden, Things 3 still allows navigation via:

* **Type Travel**: Start typing to navigate to any list
* **Quick Find** (`⌘F`): Search and jump to lists
* **Navigation popover** (`⇧⌘O`): Shows navigation UI without sidebar

#### 7\. Width Constraints

* Minimum width: \~200pt (prevents content from being too cramped)
* Maximum width: \~400pt (prevents sidebar from dominating)
* Dragging beyond bounds snaps to min/max

#### 8\. Visual Treatment (Things 3.22 - Latest)

The latest Things 3 update introduced:

* **Glass effect** in sidebar - hint of transparency
* Subtle material blur letting background colors show through
* Refined curvature on windows and controls

---

## Design Recommendations for Dispatch

### 1\. Core Components to Build

```swift
// New files to create:
Dispatch/Views/Components/macOS/
├── ResizableSidebar.swift      // Main sidebar container with drag-to-resize
├── SidebarDragHandle.swift     // Hover-revealed drag handle
└── SidebarState.swift          // Observable state + AppStorage persistence
```

### 2\. SidebarState (Persistence + Observable)

```swift
import SwiftUI

/// Manages sidebar state with persistence
class SidebarState: ObservableObject {
    /// Whether sidebar is currently visible
    @AppStorage("sidebarVisible") var isVisible: Bool = true
    
    /// Current sidebar width (when visible)
    @AppStorage("sidebarWidth") var width: CGFloat = 240
    
    /// Whether currently being dragged
    @Published var isDragging: Bool = false
    
    // Width constraints
    static let minWidth: CGFloat = 200
    static let maxWidth: CGFloat = 400
    static let defaultWidth: CGFloat = 240
    
    /// Clamp width to valid range
    func clampedWidth(_ newWidth: CGFloat) -> CGFloat {
        min(Self.maxWidth, max(Self.minWidth, newWidth))
    }
    
    /// Toggle sidebar visibility with animation
    func toggle() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible.toggle()
        }
    }
}
```

### 3\. SidebarDragHandle (Hover-Revealed)

```swift
struct SidebarDragHandle: View {
    @Binding var width: CGFloat
    @Binding var isDragging: Bool
    let minWidth: CGFloat
    let maxWidth: CGFloat
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                // Visible handle - only shows on hover
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 4, height: 40)
                    .opacity(isHovering || isDragging ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
            .onHover { hovering in
                isHovering = hovering
            }
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.resizeLeftRight.push()
                case .ended:
                    NSCursor.pop()
                }
            }
            #endif
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newWidth = width + value.translation.width
                        width = min(maxWidth, max(minWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}
```

### 4\. ResizableSidebar Container

```swift
struct ResizableSidebar<Sidebar: View, Content: View>: View {
    @StateObject private var state = SidebarState()
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: 0) {
            if state.isVisible {
                sidebar()
                    .frame(width: state.width)
                    .transition(.move(edge: .leading))
                
                SidebarDragHandle(
                    width: $state.width,
                    isDragging: $state.isDragging,
                    minWidth: SidebarState.minWidth,
                    maxWidth: SidebarState.maxWidth
                )
            }
            
            content()
                .frame(maxWidth: .infinity)
        }
        .animation(.easeOut(duration: 0.3), value: state.isVisible)
        // Keyboard shortcut: Cmd + /
        .keyboardShortcut("/", modifiers: .command)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            state.toggle()
        }
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
}
```

### 5\. Updated ContentView Integration

```swift
#if os(macOS)
private var sidebarNavigation: some View {
    ResizableSidebar {
        // Sidebar content
        List(selection: $selectedTab) {
            Label("Tasks", systemImage: DS.Icons.Entity.task)
                .tag(Tab.tasks)
            Label("Activities", systemImage: DS.Icons.Entity.activity)
                .tag(Tab.activities)
            Label("Listings", systemImage: DS.Icons.Entity.listing)
                .tag(Tab.listings)
        }
        .navigationTitle("Dispatch")
        .listStyle(.sidebar)
    } content: {
        // Detail content
        Group {
            switch selectedTab {
            case .tasks:
                TaskListView()
            case .activities:
                ActivityListView()
            case .listings:
                ListingListView()
            }
        }
        .syncNowToolbar()
    }
}
#endif
```

### 6\. Keyboard Shortcut Menu Item

Add to the macOS menu bar:

```swift
// In App.swift or equivalent
.commands {
    CommandGroup(after: .sidebar) {
        Button("Toggle Sidebar") {
            NotificationCenter.default.post(name: .toggleSidebar, object: nil)
        }
        .keyboardShortcut("/", modifiers: .command)
    }
}
```

### 7\. Trackpad Gesture Support (Advanced)

For two-finger horizontal swipe:

```swift
.gesture(
    DragGesture(minimumDistance: 30)
        .onEnded { value in
            let horizontal = value.translation.width
            if abs(horizontal) > 50 {
                withAnimation(.easeOut(duration: 0.3)) {
                    state.isVisible = horizontal > 0
                }
            }
        }
)
```

### 8\. Navigation While Collapsed

When sidebar is hidden, add a navigation popover:

```swift
// Trigger with ⇧⌘O
.keyboardShortcut("O", modifiers: [.command, .shift])

// Shows a floating navigation menu
struct NavigationPopover: View {
    @Binding var selectedTab: ContentView.Tab
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([Tab.tasks, .activities, .listings], id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title, systemImage: tab.icon)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## Current Implementation Location

* **ContentView.swift**: `Dispatch/ContentView.swift`
  * Lines 175-210: Current macOS NavigationSplitView
  * Uses standard NavigationSplitView without custom resize
* **CollapsibleHeader.swift**: `Dispatch/Views/Components/Shared/CollapsibleHeader.swift`
  * Lines 1-155: Scroll-aware header for detail views
  * Different use case - for content collapse, not sidebar
  * Can reference LinearInterpolation pattern (lines 45-47)

---

## Implementation Steps

 1. \[ \] Create `SidebarState.swift` with `@AppStorage` persistence
 2. \[ \] Create `SidebarDragHandle.swift` with hover detection + resize cursor
 3. \[ \] Create `ResizableSidebar.swift` container view
 4. \[ \] Update `ContentView.swift` to use ResizableSidebar on macOS
 5. \[ \] Add `⌘/` keyboard shortcut in Commands
 6. \[ \] Add `⇧⌘O` navigation popover for collapsed state
 7. \[ \] Test width persistence across launches
 8. \[ \] Add trackpad swipe gesture support
 9. \[ \] Polish animations (ease-out, 300ms)
10. \[ \] Consider glass effect for sidebar background (OS 26+)

---

## Design System Additions

Consider adding to `DS.Spacing`:

```swift
// Sidebar
static let sidebarMinWidth: CGFloat = 200
static let sidebarMaxWidth: CGFloat = 400
static let sidebarDefaultWidth: CGFloat = 240
static let sidebarDragHandleWidth: CGFloat = 8
static let sidebarDragHandleHeight: CGFloat = 40
```

---

## References

* [Things 3 Show/Hide Sidebar](https://culturedcode.com/things/support/articles/3238254/)
* [Things 3 Keyboard Shortcuts](https://culturedcode.com/things/support/articles/2785159/)
* [Things 3 Features - Slim Mode](https://culturedcode.com/things/features/)
* [Things 3 Blog - OS 26 Glass Effects](https://culturedcode.com/things/blog/)
