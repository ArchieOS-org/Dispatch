# DIS-37: macOS: Switch to bottom menu instead of top menu

**Linear URL:** https://linear.app/archieos/issue/DIS-37/macos-switch-to-bottom-menu-instead-of-top-menu

**Status:** Backlog
**Priority:** No priority
**Labels:** UX, macOS

## Description

Replace the top menu with a bottom menu bar like the Things app. Search and add button should be in the bottom. The top should have no menu.

---

## Things 3 macOS Bottom Bar (Actual Screenshot Reference)

### Bottom Toolbar Layout (Left to Right)

Based on the actual Things 3 interface:

| Icon | Symbol | Function |
| -- | -- | -- |
| **+** | Plus | New to-do |
| **\[+\]** | Plus in box | New checklist item |
| **📅** | Calendar | Date/schedule picker |
| **→** | Arrow | Move to another list |
| **🔍** | Magnifying glass | Search |

### Sidebar Bottom Bar (Separate)

| Position | Element |
| -- | -- |
| Left | `+ New List` button |
| Right | Settings/filter icon |

### Key Observations

1. **No labels** - Icons only, no text labels in the toolbar
2. **Simple gray icons** - Not the blue "Magic Plus" FAB style from iOS
3. **Top bar is completely empty** - Just window chrome (traffic lights)
4. **Search is on the RIGHT** (magnifying glass icon)

### Contextual Toolbar Changes (Screen-Based)

The bottom toolbar changes based on **which screen you're viewing**:

| Screen | Left Actions | Right Actions |
| -- | -- | -- |
| **List View** (TaskListView, ActivityListView, ListingListView) | * (new), \[+\] (subtask), 📅 (date)

 | → (move), 🔍 (search) |
| **Item Detail View** (WorkItemDetailView, ListingDetailView) | Claim | Delete |

**Important**: This is NOT selection-based. It's screen-based. When you navigate into a detail view, the toolbar changes to show item-specific actions.

---

## Design Recommendations for Dispatch

### 1\. Bottom Toolbar Modes (Screen-Based)

```swift
enum BottomToolbarContext {
    case list           // TaskListView, ActivityListView, ListingListView
    case itemDetail     // WorkItemDetailView
    case listingDetail  // ListingDetailView
}
```

### 2\. BottomToolbar Component

```swift
import SwiftUI

/// Things 3-style bottom toolbar for macOS
/// Icons only, no labels, changes based on current screen context
struct BottomToolbar: View {
    let context: BottomToolbarContext
    
    // List view actions
    var onNewItem: (() -> Void)?
    var onNewSubtask: (() -> Void)?
    var onSchedule: (() -> Void)?
    var onMove: (() -> Void)?
    var onSearch: (() -> Void)?
    
    // Detail view actions
    var onClaim: (() -> Void)?
    var onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            switch context {
            case .list:
                listToolbar
            case .itemDetail, .listingDetail:
                detailToolbar
            }
        }
        .frame(height: 36)
        .background {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(alignment: .top) {
                    Divider()
                }
        }
    }
    
    // MARK: - List Toolbar
    
    private var listToolbar: some View {
        HStack(spacing: 0) {
            // Left group
            HStack(spacing: 0) {
                if let onNewItem { ToolbarIconButton(icon: "plus", action: onNewItem) }
                if let onNewSubtask { ToolbarIconButton(icon: "plus.square", action: onNewSubtask) }
                if let onSchedule { ToolbarIconButton(icon: "calendar", action: onSchedule) }
            }
            
            Spacer()
            
            // Right group
            HStack(spacing: 0) {
                if let onMove { ToolbarIconButton(icon: "arrow.right", action: onMove) }
                if let onSearch { ToolbarIconButton(icon: "magnifyingglass", action: onSearch) }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
    }
    
    // MARK: - Detail Toolbar (Item/Listing)
    
    private var detailToolbar: some View {
        HStack(spacing: 0) {
            // Left: Claim
            if let onClaim {
                ToolbarIconButton(icon: "hand.raised", action: onClaim)
            }
            
            Spacer()
            
            // Right: Delete
            if let onDelete {
                ToolbarIconButton(icon: "trash", color: .red, action: onDelete)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
    }
}
```

### 3\. ToolbarIconButton Component

```swift
/// Simple icon button for bottom toolbar - no labels, hover state only
struct ToolbarIconButton: View {
    let icon: String
    var color: Color = .primary
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(color.opacity(isHovering ? 1 : 0.7))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
```

### 4\. Integration with List Views

```swift
// TaskListView.swift
struct TaskListView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                // ... task rows
            }
            
            // Bottom toolbar (macOS only)
            #if os(macOS)
            BottomToolbar(
                context: .list,
                onNewItem: { /* quick entry */ },
                onNewSubtask: { /* add subtask */ },
                onSchedule: { /* date picker */ },
                onMove: { /* move sheet */ },
                onSearch: { /* search overlay */ }
            )
            #endif
        }
        // NO .toolbar { } on macOS - top bar should be empty
    }
}
```

### 5\. Integration with Detail Views

```swift
// WorkItemDetailView.swift (add to bottom)
struct WorkItemDetailView: View {
    // ... existing code ...
    
    var body: some View {
        VStack(spacing: 0) {
            // Existing ScrollView content
            CollapsibleHeaderScrollView { offset in
                // ... header
            } content: {
                // ... content
            }
            
            // Bottom toolbar (macOS only)
            #if os(macOS)
            BottomToolbar(
                context: .itemDetail,
                onClaim: { onClaim() },
                onDelete: { /* show delete confirmation */ }
            )
            #endif
        }
    }
}
```

```swift
// ListingDetailView.swift (add to bottom)
struct ListingDetailView: View {
    // ... existing code ...
    
    var body: some View {
        VStack(spacing: 0) {
            // Existing ScrollView content
            ScrollView {
                // ... existing sections
            }
            
            // Bottom toolbar (macOS only)
            #if os(macOS)
            BottomToolbar(
                context: .listingDetail,
                onClaim: nil,  // Listings don't have claim
                onDelete: { showDeleteListingAlert = true }
            )
            #endif
        }
    }
}
```

### 6\. Sidebar Bottom Bar (Separate Component)

```swift
/// Bottom bar for the sidebar - New List + Settings
struct SidebarBottomBar: View {
    let onNewList: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onNewList) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("New List")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: onSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
```

---

## Icon Mapping for Dispatch

| Things 3 Icon | SF Symbol | Dispatch Action |
| -- | -- | -- |
| * 

 | `plus` | New Task/Activity |
| \[+\] | `plus.square` | Add Subtask |
| 📅 | `calendar` | Set Due Date |
| → | `arrow.right` | Move/Reassign |
| 🔍 | `magnifyingglass` | Search |
| Hand (detail) | `hand.raised` | Claim Item |
| Trash (detail) | `trash` | Delete Item |

---

## Current Implementation Location

* **TaskListView.swift**: `Dispatch/Views/Screens/TaskListView.swift`
  * List view - needs BottomToolbar with `.list` context
* **ActivityListView.swift**: `Dispatch/Views/Screens/ActivityListView.swift`
  * List view - needs BottomToolbar with `.list` context
* **ListingListView.swift**: `Dispatch/Views/Screens/ListingListView.swift`
  * List view - needs BottomToolbar with `.list` context
* **WorkItemDetailView.swift**: `Dispatch/Views/Components/WorkItem/WorkItemDetailView.swift`
  * Detail view - needs BottomToolbar with `.itemDetail` context
  * Has `onClaim`, `onRelease`, actions already wired
* **ListingDetailView.swift**: `Dispatch/Views/Screens/ListingDetailView.swift`
  * Detail view - needs BottomToolbar with `.listingDetail` context
  * Has `deleteListing()` action already implemented
  * No claim (listings aren't claimable)
* **ContentView.swift**: `Dispatch/ContentView.swift`
  * Remove `.syncNowToolbar()` on macOS
* **GlobalFloatingButtons.swift**: `Dispatch/Views/Components/Shared/GlobalFloatingButtons.swift`
  * iOS-only - keep as-is, macOS uses BottomToolbar instead

---

## New Files to Create

```
Dispatch/Views/Components/macOS/
├── BottomToolbar.swift          // Main toolbar (list + detail modes)
├── ToolbarIconButton.swift      // Reusable icon button with hover
└── SidebarBottomBar.swift       // Sidebar "+ New List" bar
```

---

## Implementation Steps

 1. \[ \] Create `ToolbarIconButton.swift` - icon-only button with hover state
 2. \[ \] Create `BottomToolbar.swift` with `.list` and `.itemDetail` contexts
 3. \[ \] Create `SidebarBottomBar.swift` - "+ New List" + settings
 4. \[ \] Update `TaskListView` - wrap in VStack, add BottomToolbar(.list)
 5. \[ \] Update `ActivityListView` - wrap in VStack, add BottomToolbar(.list)
 6. \[ \] Update `ListingListView` - wrap in VStack, add BottomToolbar(.list)
 7. \[ \] Update `WorkItemDetailView` - wrap in VStack, add BottomToolbar(.itemDetail)
 8. \[ \] Update `ListingDetailView` - wrap in VStack, add BottomToolbar(.listingDetail)
 9. \[ \] Remove `.syncNowToolbar()` on macOS (move sync to status bar or remove)
10. \[ \] Wire up all actions (new, search, claim, delete)
11. \[ \] Add keyboard shortcuts for toolbar actions

---

## Design System Additions

```swift
// DS.Spacing
static let bottomToolbarHeight: CGFloat = 36
static let toolbarIconSize: CGFloat = 36
static let toolbarIconFontSize: CGFloat = 15

// DS.Colors (macOS)
static let toolbarIconDefault = Color.primary.opacity(0.7)
static let toolbarIconHover = Color.primary
static let toolbarHoverBackground = Color.primary.opacity(0.08)
```

---

## Visual Reference

Key observations from screenshot:

* Toolbar is \~36pt tall
* Icons are gray, subtle
* No separation lines between icons
* Glass/material background matching sidebar
* "+ New List" in sidebar has text label
* Main toolbar icons have no labels
* **Detail view shows Claim (left) and Delete (right)**

---

## References

* [Things 3 Keyboard Shortcuts](https://culturedcode.com/things/support/articles/2785159/)
* [Things 3 Features](https://culturedcode.com/things/features/)
