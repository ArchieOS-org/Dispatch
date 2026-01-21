# Plan: Remove Unified Toolbar & Title Bar on macOS (Things 3 Style)

## Problem Analysis

Looking at the current Dispatch app vs Things 3:

**Things 3 (Gold Standard):**
- Clean title bar with ONLY traffic light window controls (red/yellow/green)
- NO title text
- NO unified toolbar row below title bar
- Content starts immediately after the minimal title area

**Dispatch (Current Issues):**
1. Window title bar shows "Dispatch" text next to traffic lights
2. Below that: a **unified toolbar row** with "Dispatch" centered and "+" button
3. This unified toolbar row is extra visual clutter that shouldn't exist

## Root Causes

1. **Unified toolbar row**: macOS's default `WindowGroup` behavior creates a unified title bar + toolbar. Need `.windowStyle(.hiddenTitleBar)` to remove it.
2. **Navigation titles**: Various `.navigationTitle()` calls propagate to window title on macOS
3. **Filter bar**: Already hidden with `#if !os(macOS)` (DONE)

## Implementation Plan

### Step 1: Hide macOS Title Bar and Toolbar (CRITICAL)
**File:** `Dispatch/DispatchApp.swift`

Add `.windowStyle(.hiddenTitleBar)` to the WindowGroup to completely remove the title bar and unified toolbar:

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .environmentObject(SyncManager.shared)
            // ... existing modifiers
    }
    .modelContainer(sharedModelContainer)
    #if os(macOS)
    .windowStyle(.hiddenTitleBar)  // <-- ADD THIS
    .commands {
        // ... existing commands
    }
    #endif
    // ... rest of scene
}
```

This single change will:
- Remove the "Dispatch" title text from the title bar
- Remove the unified toolbar row entirely (including the centered "Dispatch" and "+" button)
- Keep traffic lights visible
- Content will start immediately after the minimal window chrome

### Step 2: Remove Navigation Titles on macOS Content Views
**Files:** Already done in previous changes:
- `ContentView.swift:208-210` - `.navigationTitle("Dispatch")` wrapped in `#if !os(macOS)`
- `WorkItemListContainer.swift:107-109` - `.navigationTitle(title)` wrapped in `#if !os(macOS)`
- `ListingListView.swift:118-120` - `.navigationTitle("Listings")` wrapped in `#if !os(macOS)`

These are already implemented but may need verification.

### Step 3: Keep Filter Keyboard Shortcuts (Already Done)
- `DispatchApp.swift` already has Cmd+1/2/3 for filter switching
- `SidebarState.swift` already has notification names
- `WorkItemListContainer.swift` already has notification receivers

## Files to Modify

| File | Change |
|------|--------|
| `Dispatch/DispatchApp.swift` | Add `.windowStyle(.hiddenTitleBar)` to WindowGroup |

## Expected Result

After adding `.windowStyle(.hiddenTitleBar)`:
- macOS window shows ONLY traffic lights (no title text, no toolbar row)
- Sidebar and content area start immediately below the minimal title bar
- Bottom toolbar (with +, search icons) remains at the bottom
- Filters work via Cmd+1/2/3 keyboard shortcuts
- iOS/iPadOS completely unchanged

## Notes

- Per Context7 research, `.windowStyle(.hiddenTitleBar)` is the key modifier
- Xcode preview may not show this correctly - must build and run to verify
- For macOS 15.0+, can also use `.toolbar(removing: .title)` for finer control
