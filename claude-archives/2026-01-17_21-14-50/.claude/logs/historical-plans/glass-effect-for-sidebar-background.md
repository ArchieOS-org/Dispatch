# Glass Effect for Sidebar Background

## Overview

Add a Liquid Glass background effect to the macOS sidebar, following Apple's WWDC 2025 design language.

**References:**
- [Build a SwiftUI app with the new design - WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Implementing the glassEffect in SwiftUI](https://livsycode.com/swiftui/implementing-the-glasseffect-in-swiftui/)
- [Glassifying custom SwiftUI views](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/)

## Current State

### Existing Glass Implementation
`Dispatch/Design/Effects/GlassEffect.swift` has:
- `glassCircleBackground()` - circular glass for buttons only
- iOS 26+ uses `.glassEffect(.regular.interactive())`
- Fallback: `.ultraThinMaterial` + Circle clip + stroke border + shadow

### Sidebar Implementation
`Dispatch/Views/Components/macOS/ResizableSidebar.swift`:
- Currently has **no background** on sidebar
- Sidebar is wrapped in `HStack` with content
- Uses `.clipped()` modifier

---

## Implementation Plan

### Step 1: Extend GlassEffect.swift with Sidebar Glass Modifier

**File:** `Dispatch/Design/Effects/GlassEffect.swift`

Add new modifier for rectangular glass (sidebar/panels):

```swift
/// Applies a glass effect background for sidebars and panels on macOS 26+.
/// Falls back to regularMaterial on earlier versions.
@ViewBuilder
func glassSidebarBackground() -> some View {
    #if os(macOS)
    if #available(macOS 26.0, *) {
        self
            .glassEffect(.regular)
            .containerShape(RoundedRectangle(cornerRadius: 0))
    } else {
        self
            .background(.regularMaterial)
    }
    #else
    self.background(.regularMaterial)
    #endif
}
```

**Design decisions:**
- Use `.regular` (not `.interactive`) for static sidebar - less visual noise
- No corner radius for edge-to-edge sidebar
- `.regularMaterial` fallback (more opaque than ultraThin, better for sidebars)
- macOS-only guard since sidebar is macOS-only

### Step 2: Apply Glass Background to Sidebar

**File:** `Dispatch/Views/Components/macOS/ResizableSidebar.swift`

Modify sidebar rendering (lines 28-32):

```swift
if state.shouldShowSidebar {
    sidebar()
        .frame(width: state.displayWidth)
        .glassSidebarBackground()  // NEW: Add glass effect
        .clipped()
}
```

### Step 3: Handle Content Sampling (Optional Enhancement)

If sidebar glass samples content behind it (Liquid Glass behavior), may need:

```swift
.overlay(alignment: .leading) {
    // Drag handle overlay stays on top of glass
    UnifiedDragHandle(state: state, reduceMotion: reduceMotion)
        .offset(...)
}
```

The current overlay-based drag handle should work correctly.

### Step 4: Consider GlassEffectContainer (Optional)

If multiple glass elements exist in sidebar content, wrap in container:

```swift
if #available(macOS 26.0, *) {
    GlassEffectContainer {
        sidebar()
            .frame(width: state.displayWidth)
            .glassEffect(.regular)
            .clipped()
    }
}
```

---

## Files to Modify

| File | Change |
|------|--------|
| `Dispatch/Design/Effects/GlassEffect.swift` | Add `glassSidebarBackground()` modifier |
| `Dispatch/Views/Components/macOS/ResizableSidebar.swift` | Apply glass background to sidebar |

## Testing Checklist

- [ ] macOS 26+: Verify Liquid Glass renders correctly
- [ ] macOS 15: Verify `.regularMaterial` fallback works
- [ ] Drag to resize: Glass effect persists smoothly
- [ ] Collapse/expand animation: No visual artifacts
- [ ] Dark mode: Glass adapts appropriately
- [ ] Light mode: Glass adapts appropriately
- [ ] Reduce transparency accessibility: Effect respects setting

## Technical Notes

### Glass Variants (iOS 26+/macOS 26+)
- `.regular` - balanced, legible (default) ← **Use this**
- `.clear` - more transparent, needs background dimming
- `.identity` - conditionally disable glass

### Glass Modifiers
- `.interactive()` - responds to gestures, more dynamic
- `.tint(color)` - blends color into glass

### Fallback Materials (pre-macOS 26)
- `.ultraThinMaterial` - very transparent
- `.thinMaterial` - slightly less transparent
- `.regularMaterial` - balanced opacity ← **Use this**
- `.thickMaterial` - more opaque

## Scope

**In scope:**
- Glass background for macOS sidebar
- Fallback for older macOS versions

**Out of scope:**
- iOS/iPadOS sidebar glass (uses NavigationSplitView)
- Glass for other UI elements (future work)
- Custom tinting or color blending
