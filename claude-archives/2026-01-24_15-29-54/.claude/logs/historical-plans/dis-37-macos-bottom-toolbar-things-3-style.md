# DIS-37: macOS Bottom Toolbar (Things 3 Style)

## Summary

Replace the top toolbar with a Things 3-style bottom toolbar on macOS. The toolbar is **screen-context-based** (changes based on current view), shows **icons only** with hover states, and leaves the top bar empty (just window chrome).

---

## New Files to Create

### 1. `Dispatch/Views/Components/macOS/ToolbarIconButton.swift`
Icon-only button (36pt) with hover state:
- Props: `icon: String`, `action: () -> Void`, `accessibilityLabel: String`, `isDestructive: Bool = false`
- Hover: opacity 0.6 → 1.0, subtle background highlight
- Uses `@Environment(\.accessibilityReduceMotion)` for animation control

### 2. `Dispatch/Views/Components/macOS/BottomToolbar.swift`
Context-aware toolbar container:
```swift
enum ToolbarContext {
    case taskList, activityList, listingList   // List contexts
    case workItemDetail, listingDetail          // Detail contexts
}
```

**List context layout:**
- Left: `+` (new), `[+]` (subtask - placeholder), `calendar` (schedule - placeholder)
- Right: `arrow.right` (move - placeholder), `magnifyingglass` (search)

**Detail context layout:**
- Left: Claim button (hand.raised)
- Right: Delete button (trash, red)

Props: `context`, `onNew`, `onSearch`, `onClaim`, `claimState`, `onDelete`

### 3. `Dispatch/Views/Components/macOS/SidebarBottomBar.swift` (Phase 2 - optional)
Sidebar-specific bar with "+ New List" and settings icon.

---

## Files to Modify

### 4. `Dispatch/Design/Spacing.swift`
Add bottom toolbar constants (after line 159):
```swift
// MARK: - Bottom Toolbar (macOS)
static let bottomToolbarHeight: CGFloat = 44
static let bottomToolbarButtonSize: CGFloat = 36
static let bottomToolbarIconSize: CGFloat = 18
static let bottomToolbarPadding: CGFloat = 12
```

### 5. `Dispatch/ContentView.swift`
Modify macOS `sidebarNavigation` (lines 177-205):
- Add `@State private var showMacOSQuickEntry = false`
- Add `@State private var showMacOSSearch = false`
- Add `.safeAreaInset(edge: .bottom)` with `BottomToolbar` to the NavigationStack
- Remove `.syncNowToolbar()` from macOS (keep sync in menu bar command)
- Add QuickEntrySheet presentation for macOS

### 6. `Dispatch/Views/Screens/TaskListView.swift`
- Remove macOS toolbar block (lines ~184-194): `#if os(macOS) .toolbar { ToolbarItem... }`
- Keep the quick entry sheet but trigger it from ContentView

### 7. `Dispatch/Views/Screens/ActivityListView.swift`
- Remove macOS toolbar block (same pattern as TaskListView)

### 8. `Dispatch/Views/Screens/ListingListView.swift`
- Remove macOS toolbar block (lines ~162-172)

### 9. `Dispatch/Views/Screens/ListingDetailView.swift`
- Remove macOS toolbar (lines ~132-141 with OverflowMenu)
- Detail context handled by BottomToolbar in ContentView

### 10. `Dispatch/Views/Modifiers/SyncNowToolbar.swift`
- Make macOS section return `EmptyModifier` or remove macOS toolbar item
- Sync remains available via Cmd+R menu bar shortcut (already in DispatchApp.swift)

### 11. `Dispatch/DispatchApp.swift`
Add keyboard shortcuts in `.commands` block:
- Cmd+N: New item (post notification)
- Cmd+F: Search (post notification)

---

## Implementation Order

### Phase 1: Foundation
1. Add spacing constants to `Spacing.swift`
2. Create `ToolbarIconButton.swift`
3. Create `BottomToolbar.swift`

### Phase 2: Integration
4. Modify `ContentView.swift` to add bottom toolbar
5. Remove macOS toolbar from `TaskListView.swift`
6. Remove macOS toolbar from `ActivityListView.swift`
7. Remove macOS toolbar from `ListingListView.swift`
8. Remove macOS toolbar from `ListingDetailView.swift`
9. Modify `SyncNowToolbar.swift` to skip macOS

### Phase 3: Polish
10. Add keyboard shortcuts to `DispatchApp.swift`
11. Test all interactions and verify hover states

---

## Key Patterns to Follow

**Hover state** (from ResizableSidebar.swift):
```swift
@State private var isHovering = false
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.onHover { hovering in isHovering = hovering }
.opacity(isHovering ? 1 : 0.6)
.animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovering)
```

**Glass background** (from GlassEffect.swift):
```swift
.glassSidebarBackground()  // or .regularMaterial fallback
```

**Platform guards**:
```swift
#if os(macOS)
// macOS-specific code
#endif
```

---

## Design Specifications (from Linear issue)

| Element | Value |
|---------|-------|
| Toolbar height | 44pt |
| Button size | 36pt |
| Icon size | 18pt (SF Symbol) |
| Icon opacity (default) | 0.6 |
| Icon opacity (hover) | 1.0 |
| Background | Glass material with top separator |

**SF Symbols:**
- New: `plus`
- Subtask: `plus.square`
- Schedule: `calendar`
- Move: `arrow.right`
- Search: `magnifyingglass`
- Claim: `hand.raised`
- Delete: `trash` (red)

---

## Critical Files Reference

| File | Path |
|------|------|
| ContentView | `Dispatch/ContentView.swift` |
| TaskListView | `Dispatch/Views/Screens/TaskListView.swift` |
| ActivityListView | `Dispatch/Views/Screens/ActivityListView.swift` |
| ListingListView | `Dispatch/Views/Screens/ListingListView.swift` |
| ListingDetailView | `Dispatch/Views/Screens/ListingDetailView.swift` |
| ResizableSidebar | `Dispatch/Views/Components/macOS/ResizableSidebar.swift` |
| GlassEffect | `Dispatch/Design/Effects/GlassEffect.swift` |
| Spacing | `Dispatch/Design/Spacing.swift` |
| SyncNowToolbar | `Dispatch/Views/Modifiers/SyncNowToolbar.swift` |
| DispatchApp | `Dispatch/DispatchApp.swift` |

---

## Testing Checklist

- [ ] Bottom toolbar appears on macOS list views
- [ ] Toolbar context switches to detail mode on navigation
- [ ] Hover states animate correctly
- [ ] Cmd+N opens QuickEntrySheet
- [ ] Cmd+F triggers search
- [ ] iOS/iPadOS unchanged (GlobalFloatingButtons still works)
- [ ] Accessibility: reduceMotion disables animations
- [ ] Top bar is empty (just window chrome)
