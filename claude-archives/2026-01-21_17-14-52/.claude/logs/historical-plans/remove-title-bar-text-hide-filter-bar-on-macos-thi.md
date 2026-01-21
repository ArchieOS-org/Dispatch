# Plan: Remove Title Bar Text & Hide Filter Bar on macOS (Things 3 Style)

## Problem Analysis

Looking at the screenshot comparison:

**Things 3 (Left - Gold Standard):**
- Clean title bar with just traffic light window controls
- No text in title bar
- No tab bar / filter bar below title bar
- Content starts immediately after title bar

**Dispatch (Right - Current):**
- Title bar shows "Dispatch" text
- Below that: a row with "Dispatch" label + segmented filter bar ("Filter", "My Tasks", "Others'", "Unclaimed")
- This creates unnecessary visual clutter that Things 3 doesn't have

## Root Causes

1. **Title bar text**: `ContentView.swift:208` - `.navigationTitle("Dispatch")` on the sidebar List
2. **Filter bar visible on macOS**: `WorkItemListContainer.swift:94-96` - `SegmentedFilterBar` is rendered at the top of every list view, unconditionally on all platforms

## Implementation Plan

### Step 1: Remove Navigation Title on macOS Sidebar
**File:** `Dispatch/ContentView.swift`

Change line 208 from:
```swift
.navigationTitle("Dispatch")
```
To either remove it entirely for macOS or use an empty string:
```swift
#if os(macOS)
// No navigation title on macOS - just traffic lights
#else
.navigationTitle("Dispatch")
#endif
```

### Step 2: Hide Filter Bar on macOS (Keep Functionality)
**File:** `Dispatch/Views/Containers/WorkItemListContainer.swift`

The user wants to "hide it in the UI" but "not kill the tabs option". This means:
- Keep the `@State private var selectedFilter: ClaimFilter = .mine` state
- Keep the filtering logic in `filteredItems`
- Only hide the `SegmentedFilterBar` view on macOS

Modify lines 91-106:
```swift
@ViewBuilder
private var content: some View {
    VStack(spacing: 0) {
        #if !os(macOS)
        // Filter bar - iOS/iPad only (macOS uses keyboard shortcuts or menu)
        SegmentedFilterBar(selection: $selectedFilter) { filter in
            filter.displayName(forActivities: isActivityList)
        }
        #endif

        // Content
        if isEmpty {
            emptyStateView
        } else {
            listView
        }
    }
    .navigationTitle(title)
}
```

### Step 3: Add Filter Keyboard Shortcuts (macOS)
**File:** `Dispatch/DispatchApp.swift`

Add keyboard shortcuts for filter switching since the UI filter bar will be hidden:
```swift
CommandGroup(after: .newItem) {
    // ... existing shortcuts ...

    Divider()

    Button("My Tasks") {
        NotificationCenter.default.post(name: .filterMine, object: nil)
    }
    .keyboardShortcut("1", modifiers: .command)

    Button("Others' Tasks") {
        NotificationCenter.default.post(name: .filterOthers, object: nil)
    }
    .keyboardShortcut("2", modifiers: .command)

    Button("Unclaimed") {
        NotificationCenter.default.post(name: .filterUnclaimed, object: nil)
    }
    .keyboardShortcut("3", modifiers: .command)
}
```

### Step 4: Wire Up Filter Notifications
**File:** `Dispatch/Views/Components/macOS/SidebarState.swift`

Add new notification names:
```swift
extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let newItem = Notification.Name("newItem")
    static let openSearch = Notification.Name("openSearch")
    static let filterMine = Notification.Name("filterMine")
    static let filterOthers = Notification.Name("filterOthers")
    static let filterUnclaimed = Notification.Name("filterUnclaimed")
}
```

### Step 5: Handle Filter Changes in WorkItemListContainer
**File:** `Dispatch/Views/Containers/WorkItemListContainer.swift`

Add notification receivers on macOS:
```swift
#if os(macOS)
.onReceive(NotificationCenter.default.publisher(for: .filterMine)) { _ in
    selectedFilter = .mine
}
.onReceive(NotificationCenter.default.publisher(for: .filterOthers)) { _ in
    selectedFilter = .others
}
.onReceive(NotificationCenter.default.publisher(for: .filterUnclaimed)) { _ in
    selectedFilter = .unclaimed
}
#endif
```

## Files to Modify

| File | Change |
|------|--------|
| `Dispatch/ContentView.swift` | Remove `.navigationTitle("Dispatch")` on macOS |
| `Dispatch/Views/Containers/WorkItemListContainer.swift` | Hide SegmentedFilterBar on macOS, add notification receivers |
| `Dispatch/DispatchApp.swift` | Add Cmd+1/2/3 filter shortcuts |
| `Dispatch/Views/Components/macOS/SidebarState.swift` | Add filter notification names |

## Result

After implementation:
- macOS window will have just traffic lights (no title text)
- Filter bar will be hidden on macOS
- Filters still work via Cmd+1 (My Tasks), Cmd+2 (Others'), Cmd+3 (Unclaimed)
- iOS/iPadOS unchanged (filter bar still visible, navigation titles preserved)
