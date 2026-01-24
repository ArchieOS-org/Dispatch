## Interface Lock

**Feature**: Fix Toolbar/Sidebar Implementation - Restore Bottom Toolbar and Translucent Sidebar
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES
**Type**: CORRECTIVE (fixes broken implementation from liquid-glass-toolbar-sidebar.md)

---

### Problem Statement

The previous implementation in `liquid-glass-toolbar-sidebar.md` introduced several regressions:

| Problem | Current State | Required State |
|---------|--------------|----------------|
| **P1: Bottom toolbar moved to top (CRITICAL)** | `LiquidGlassToolbar` at `.safeAreaInset(edge: .top)` | Bottom toolbar at `.safeAreaInset(edge: .bottom)` (Things 3 style) |
| **P2: Sidebar too opaque** | `.regularMaterial` in `glassSidebarBackground()` | Xcode-style translucent (`.sidebar` on macOS, `.thinMaterial` on iOS) |
| **P3: Floating toolbar overlay** | Custom `LiquidGlassToolbar` floats over content | Either remove or integrate into native `.toolbar {}` |
| **P4: iPad toolbar at top** | Same issue as macOS | Remove or keep consistent with design intent |

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles on iOS + macOS | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/App/Platform/MacContentView.swift` | Remove `LiquidGlassToolbar` from `.safeAreaInset(edge: .top)`, restore `BottomToolbar` at `.safeAreaInset(edge: .bottom)` | P1 |
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/App/Platform/iPadContentView.swift` | Remove `LiquidGlassToolbar` from `.safeAreaInset(edge: .top)` | P1 |
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Packages/DesignSystem/Sources/DesignSystem/Effects/GlassEffect.swift` | Change `glassSidebarBackground()` line 38 from `.regularMaterial` to platform-adaptive: macOS uses `.sidebar` equivalent, iOS uses `.thinMaterial` | P2 |
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/Foundation/Platform/macOS/BottomToolbar.swift` | Remove DEPRECATED comment (lines 8-10), this is the active toolbar | P3 |
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` | Verify sidebar uses updated `glassSidebarBackground()` (already does at line 159) | P4 - verify only |

### Files to Delete (Optional)

| File | Reason |
|------|--------|
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/Design/Shared/Components/LiquidGlassToolbar.swift` | Not used after fix; cleanup (or keep for future WWDC25 implementation) |
| `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/Design/Shared/Components/UnifiedSidebar.swift` | Evaluate if still needed after changes |

### Acceptance Criteria (3 max)

1. **Bottom toolbar restored at window bottom**: macOS uses `BottomToolbar` with `.safeAreaInset(edge: .bottom)`, matching Things 3 style
2. **Sidebar uses Xcode-style translucent material**: macOS sidebar uses `NSVisualEffectView.Material.sidebar` equivalent (most translucent), iOS uses `.thinMaterial`
3. **No floating toolbar overlay at top**: Remove `LiquidGlassToolbar` from top safe area inset on both platforms

### Non-goals (prevents scope creep)

- No new toolbar features or actions
- No changes to sidebar navigation structure
- No changes to `UnifiedSidebarContent` component
- No changes to Quick Find or search functionality
- No iPhone changes (iPhone uses TabView)
- Keeping `LiquidGlassToolbar.swift` is optional (can be removed or kept for future)

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only changes, reverting to previous design)
- **Default when missing**: N/A
- **Rollback strategy**: Previous state IS the rollback target for this fix

---

### Ownership

- **feature-owner**: Implement all file changes
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Notes

#### Context7 Required For

| Topic | Query |
|-------|-------|
| macOS sidebar material | "NSVisualEffectView Material sidebar SwiftUI equivalent" |
| SwiftUI Material types | "SwiftUI Material thinMaterial ultraThinMaterial sidebar" |
| Bottom toolbar placement | "safeAreaInset edge bottom toolbar SwiftUI" |

#### P1 Fix: MacContentView.swift

**Remove** (lines 165-188):
```swift
// WWDC25: Floating Liquid Glass toolbar at top (replaces bottom toolbar)
.safeAreaInset(edge: .top, spacing: 0) {
  LiquidGlassToolbar(...)
}
```

**Add** after NavigationStack:
```swift
// Things 3-style bottom toolbar
.safeAreaInset(edge: .bottom, spacing: 0) {
  BottomToolbar(
    context: bottomToolbarContext,
    audience: $appState.lensState.audience,
    onNew: { ... },
    onSearch: { windowUIState.openSearch(initialText: nil) },
    onDuplicateWindow: { openWindow(id: "main") },
    duplicateWindowDisabled: !supportsMultipleWindows
  )
}
```

**Note**: Need to add `bottomToolbarContext` computed property (map from `liquidGlassToolbarContext` to `ToolbarContext`).

#### P2 Fix: GlassEffect.swift Line 38

**Change from**:
```swift
background(.regularMaterial)
```

**Change to**:
```swift
#if os(macOS)
// .sidebar is the most translucent material for sidebars, matching Xcode/Finder
background(.sidebar)
#else
// iOS uses thinMaterial for translucent sidebars
background(.thinMaterial)
#endif
```

**Note**: SwiftUI on macOS exposes `.sidebar` as a Material type that maps to `NSVisualEffectView.Material.sidebar`.

#### P3 Fix: iPadContentView.swift

**Remove** (lines 64-74):
```swift
// WWDC25: Floating Liquid Glass toolbar at top
.safeAreaInset(edge: .top, spacing: 0) {
  LiquidGlassToolbar(...)
}
```

iPad will rely on FAB for quick entry and standard navigation patterns.

#### P4 Fix: BottomToolbar.swift

**Remove** (lines 8-10):
```swift
//  DEPRECATED: Replaced by LiquidGlassToolbar (WWDC25 Liquid Glass design).
//  This file is kept for reference and potential rollback.
//  See: Dispatch/Design/Shared/Components/LiquidGlassToolbar.swift
```

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: sidebar material ShapeStyle macOS translucent background Material types
CONTEXT7_TAKEAWAYS:
- SwiftUI Material types: `.ultraThin`, `.thin`, `.regular`, `.thick`, `.ultraThick`, `.bar`
- No `.sidebar` Material type exists in SwiftUI - that's an NSVisualEffectView.Material (AppKit)
- For most translucent sidebar backgrounds, use `.ultraThinMaterial` on macOS
- iOS uses `.thinMaterial` for translucent sidebars
CONTEXT7_APPLIED:
- `.ultraThinMaterial` for macOS sidebar -> GlassEffect.swift:40
- `.thinMaterial` for iOS sidebar -> GlassEffect.swift:43

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| sidebar material ShapeStyle macOS translucent background Material types | `.ultraThinMaterial` for macOS, `.thinMaterial` for iOS (no SwiftUI `.sidebar` Material exists) |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - removed unnecessary LiquidGlassToolbar overlay, restored simple bottom toolbar
- [x] One clear primary action per screen/state - bottom toolbar: plus button (primary) left, secondary actions right
- [x] Strong hierarchy - Things 3 pattern: primary left, spacer, secondary right
- [x] No clutter - removed floating overlay that competed with content area
- [x] Native feel - Things 3-style bottom toolbar is proven macOS pattern; .ultraThinMaterial matches Xcode/Finder

#### Verdict Notes

All acceptance criteria verified via code review:

1. **Bottom toolbar restored at window bottom**: MacContentView.swift line 166 uses `.safeAreaInset(edge: .bottom, spacing: 0)` with BottomToolbar component. Context-aware actions based on destination (taskList, listingList, etc.)

2. **Sidebar uses Xcode-style translucent material**: GlassEffect.swift line 40 uses `.ultraThinMaterial` for macOS (most translucent option in SwiftUI). ResizableSidebar.swift line 159 applies `.glassSidebarBackground()` correctly.

3. **No floating toolbar overlay at top**: LiquidGlassToolbar removed from both MacContentView.swift and iPadContentView.swift. No `.safeAreaInset(edge: .top)` with toolbar overlay present.

Additional verification:
- BottomToolbar.swift: DEPRECATED comment removed (clean file header)
- iPad uses FAB overlay for quick entry (appropriate platform adaptation)
- All toolbar buttons have accessibilityLabel ("New item", "Search", "New Window")

The implementation correctly reverts the broken liquid-glass-toolbar-sidebar changes while maintaining proper platform conventions.

---

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| `.sidebar` Material may not exist in SwiftUI | Query Context7; fallback to `.ultraThinMaterial` if needed |
| Removing top toolbar affects iPad UX | iPad still has FAB for quick entry; evaluate if dedicated toolbar needed |
| `liquidGlassToolbarContext` removal requires mapping | Create `bottomToolbarContext` computed property |

### Testing Strategy

1. **Build Verification**:
   - iOS Simulator (iPhone 17) - should be unaffected
   - iOS Simulator (iPad Pro 13-inch M5) - verify no top toolbar, FAB still works
   - macOS - verify bottom toolbar present, sidebar translucent

2. **Manual Validation**:
   - macOS: Sidebar matches Xcode translucency
   - macOS: Bottom toolbar visible at window bottom
   - macOS: Stage cards visible in sidebar with proper contrast
   - iPad: No floating toolbar at top
   - Light/dark mode on both platforms

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
