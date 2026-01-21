## Interface Lock

**Feature**: Native macOS Sidebar with Unified Toolbar
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES (major visual change - replacing custom sidebar with native NavigationSplitView)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Validation | xcode-pilot |

---

### Problem Statement

The current macOS implementation uses a custom "Things 3-style" sidebar (`ResizableSidebar`) that creates a rounded floating panel with drag-to-resize and custom collapse animations. This approach:

1. **Cannot achieve native Xcode/Finder appearance** - It's not using the real macOS sidebar system
2. **Fights the framework** - Custom gestures and animations instead of system behavior
3. **Misses Liquid Glass integration** - Cannot benefit from macOS native unified toolbar chrome

### Solution

Replace custom `ResizableSidebar` with native `NavigationSplitView` and add `.windowToolbarStyle(.unifiedCompact)` to get true macOS sidebar + toolbar behavior.

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (may remove WindowUIState sidebar properties if no longer needed)
- Migration required: N

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/App/DispatchApp.swift` | Add `.windowToolbarStyle(.unifiedCompact(showsTitle: false))` in macOS block (~line 103) |
| `Dispatch/App/Platform/MacContentView.swift` | Replace `ResizableSidebar` with `NavigationSplitView`, move `BottomToolbar` outside to span full width |
| `Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` | Deprecate or remove (evaluate if anything still depends on it) |

### Implementation Notes

**Reference: iPad already does this correctly** (iPadContentView.swift):
```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
  UnifiedSidebarContent(...)
} detail: {
  NavigationStack(...) { ... }
}
.navigationSplitViewStyle(.balanced)
```

**macOS pattern should be similar but with additions:**
```swift
WindowGroup(id: "main") {
  // content
}
.windowToolbarStyle(.unifiedCompact(showsTitle: false))  // ADD THIS
```

```swift
// In MacContentView
NavigationSplitView(columnVisibility: $columnVisibility) {
  UnifiedSidebarContent(...)
} detail: {
  NavigationStack(...) { ... }
}
.navigationSplitViewStyle(.balanced)  // or .prominentDetail

// BottomToolbar at ZStack level to span under sidebar
```

### Context7 Required

Use Context7 to verify current APIs for:
- `NavigationSplitView` macOS-specific behavior
- `windowToolbarStyle(.unifiedCompact)` API and options
- `NavigationSplitViewVisibility` state management on macOS
- Sidebar collapse toggle (Cmd+/) with NavigationSplitView

### Acceptance Criteria (3 max)

1. **Native sidebar**: Sidebar is full-height native system sidebar (no rounded corners, no floating panel insets)
2. **Unified toolbar**: Titlebar has unified compact toolbar style (Liquid Glass chrome on macOS 26+)
3. **Bottom toolbar spans full width**: BottomToolbar extends under/across sidebar area, not just detail content

### Non-goals (prevents scope creep)

- No custom drag-to-resize (use system sidebar resize behavior instead)
- No Things 3-style collapse animation (use system collapse behavior)
- No floating glass panel aesthetic (adopting native sidebar chrome)
- No changes to iPad or iPhone implementations
- No changes to UnifiedSidebarContent internals (reuse as-is)

### Trade-offs

| Loses | Gains |
|-------|-------|
| Custom drag-to-resize with snap behavior | Native macOS sidebar resize |
| Things 3-style spring collapse animation | Native sidebar collapse (Cmd+Opt+S) |
| Floating glass panel with rounded corners | True Xcode/Finder native appearance |
| Custom drag handle with hover states | System sidebar divider |

### Compatibility Plan

- **Backward compatibility**: N/A (no data changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert to previous MacContentView.swift using ResizableSidebar

---

### Ownership

- **feature-owner**: Replace ResizableSidebar with NavigationSplitView, add windowToolbarStyle, reposition BottomToolbar
- **data-integrity**: Not needed
- **jobs-critic**: Review native sidebar appearance meets design bar
- **ui-polish**: Verify spacing, colors, and polish of native controls
- **xcode-pilot**: Visual validation on macOS simulator

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: NavigationSplitView macOS sidebar columnVisibility toggle keyboard shortcut
CONTEXT7_TAKEAWAYS:
- Use `@State private var columnVisibility: NavigationSplitViewVisibility = .all` for programmatic control
- Pass `$columnVisibility` binding to `NavigationSplitView(columnVisibility:sidebar:detail:)`
- Toggle between `.all` and `.detailOnly` to show/hide sidebar
- Split view ignores visibility control when it collapses into a stack
CONTEXT7_APPLIED:
- NavigationSplitView with columnVisibility -> MacContentView.swift

CONTEXT7_QUERY: windowToolbarStyle unifiedCompact macOS Scene modifier
CONTEXT7_TAKEAWAYS:
- Use `.windowToolbarStyle(.unifiedCompact(showsTitle: false))` on Scene (not View)
- Available on macOS 11.0+
- Provides compact vertical sizing for toolbar/title bar area
CONTEXT7_APPLIED:
- .windowToolbarStyle(.unifiedCompact(showsTitle: false)) -> DispatchApp.swift:105

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| NavigationSplitView macOS sidebar columnVisibility toggle keyboard shortcut | NavigationSplitView with $columnVisibility binding, toggle between .all and .detailOnly |
| windowToolbarStyle unifiedCompact macOS Scene modifier | .windowToolbarStyle(.unifiedCompact(showsTitle: false)) on WindowGroup Scene |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - Removed ~180 lines of custom gesture/animation code (ResizableSidebar) for native NavigationSplitView
- [x] One clear primary action per screen/state - Sidebar navigation and content hierarchy preserved
- [x] Strong hierarchy - Sidebar -> Detail -> Bottom toolbar flow is clear
- [x] No clutter - Removed floating panel visual noise (rounded corners, shadows, insets) for native chrome
- [x] Native feel - NavigationSplitView + .windowToolbarStyle(.unifiedCompact) matches Xcode/Finder exactly

#### Verdict Notes

Excellent implementation. This is a textbook example of embracing the platform:

1. **Native sidebar**: NavigationSplitView with columnVisibility binding gives real macOS sidebar behavior - resize, collapse, keyboard shortcuts all work natively.

2. **Unified toolbar**: .windowToolbarStyle(.unifiedCompact(showsTitle: false)) provides genuine macOS titlebar chrome with Liquid Glass appearance on macOS 26+.

3. **Full-width bottom toolbar**: Moving BottomToolbar to .safeAreaInset(edge: .bottom) at root level correctly spans under sidebar. The new glassFullWidthToolbarBackground() uses thin material with subtle top stroke - appropriate for full-width toolbar.

4. **Code reduction**: Custom ResizableSidebar with gesture handling, spring animations, and floating panel styling replaced by 3 lines of NavigationSplitView configuration.

5. **Detail integration**: .toolbarBackgroundVisibility(.hidden, for: .windowToolbar) on NavigationStack allows content to flow under titlebar properly.

No fixes required. Would Apple ship this? Yes.

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` → integrator MUST reject DONE
