## Interface Lock

**Feature**: Fix Toolbar/Sidebar Visual Issues (Dark Nav Bar + Opaque Row Backgrounds)
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

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
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

---

## Problem Analysis

### Problem 1: Dark Top Navigation Bar on macOS Detail Views

**Root Cause**:
The NavigationStack inside `MacContentView.swift` renders its own navigation bar when pushing detail views. The modifier `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` in `AppShellView.swift` only hides the **window toolbar** (NSToolbar), NOT the SwiftUI NavigationStack's internal navigation bar.

**Evidence**:
When navigating to detail views (PropertyDetailView, ListingDetailView, etc.), a dark/opaque bar appears with:
- Back button (chevron.left) on left
- OverflowMenu ("...") on right

**Current Code** (`AppShellView.swift:25`):
```swift
.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)  // Only hides NSToolbar!
```

**Fix**:
Add `.toolbarBackgroundVisibility(.hidden, for: .navigationBar)` to hide the NavigationStack's navigation bar background on macOS. This must be applied to the NavigationStack in `MacContentView.swift`.

---

### Problem 2: Opaque Sidebar Row Backgrounds (Navigation Tabs Section)

**Root Cause**:
In `UnifiedSidebar.swift`, the Stage cards Section (line 52-67) correctly has `.listRowBackground(Color.clear)`, but the Navigation tabs Section (lines 69-81) is **MISSING** this modifier.

**Evidence**:
Stage cards have clear backgrounds, but navigation rows (Workspace, Properties, Listings, Realtors) show opaque gray backgrounds against the translucent sidebar material.

**Current Code** (`UnifiedSidebar.swift:69-81`):
```swift
// Navigation tabs section
Section {
  ForEach(AppTab.sidebarTabs) { tab in
    SidebarMenuRow(...)
    .tag(SidebarDestination.tab(tab))
  }
}
.accessibilityElement(children: .contain)
.accessibilityLabel("Navigation")
// MISSING: .listRowBackground(Color.clear)
```

**Fix**:
Add `.listRowBackground(Color.clear)` to the navigation tabs Section.

---

### Problem 3: Sidebar Does Not Match Xcode's Native Appearance

**Root Cause**:
The sidebar uses custom material backgrounds with `.scrollContentBackground(.hidden)` which fights the native `.listStyle(.sidebar)` styling. Native macOS sidebars (Xcode, Finder) use the system-provided translucent background without custom overlays.

**Current Approach**:
1. `UnifiedSidebar.swift:84`: `.scrollContentBackground(.hidden)` - Hides native List background
2. `UnifiedSidebar.swift:94-98`: Custom `.thinMaterial` background via Rectangle
3. `ResizableSidebar.swift:157-160`: `.glassSidebarBackground()` which uses `.ultraThinMaterial`
4. `GlassEffect.swift:38-44`: Defines macOS sidebar as `background(.ultraThinMaterial)`

**Result**: Double-layered materials fighting each other; not matching native Xcode sidebar appearance.

**Fix Options** (in order of preference):

1. **Option A: Trust Native Styling**
   - Remove `.scrollContentBackground(.hidden)` from UnifiedSidebar
   - Remove custom background from UnifiedSidebar (iOS `#if` block)
   - Keep ResizableSidebar's `.glassSidebarBackground()` for the container only
   - Let `.listStyle(.sidebar)` provide native translucent background

2. **Option B: Single Material Layer**
   - Keep `.scrollContentBackground(.hidden)`
   - Apply material only at ONE level (ResizableSidebar container OR UnifiedSidebar, not both)
   - Ensure `.listRowBackground(Color.clear)` on ALL sections

**Recommendation**: Option A for macOS (trust native), Option B for iOS (NavigationSplitView needs explicit material).

---

## Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `/Dispatch/App/Platform/MacContentView.swift` | Add `.toolbarBackgroundVisibility(.hidden, for: .navigationBar)` to NavigationStack | P0 |
| `/Dispatch/Design/Shared/Components/UnifiedSidebar.swift` | Add `.listRowBackground(Color.clear)` to navigation tabs Section | P0 |
| `/Dispatch/Design/Shared/Components/UnifiedSidebar.swift` | Conditionally remove `.scrollContentBackground(.hidden)` on macOS | P1 |
| `/Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` | Review if `.glassSidebarBackground()` is needed when using native styling | P1 |

---

### Acceptance Criteria (3 max)

1. **No dark navigation bar**: Detail views on macOS show transparent/glass navigation bar background, not opaque dark bar
2. **Clear sidebar row backgrounds**: Both stage cards AND navigation tab rows have transparent backgrounds against the sidebar material
3. **Native Xcode-like sidebar**: macOS sidebar uses system translucent appearance with proper selection highlighting (rounded, translucent)

### Non-goals (prevents scope creep)

- No changes to sidebar navigation structure or content
- No changes to iPad NavigationSplitView structure
- No changes to iPhone (uses TabView, not sidebar)
- No new toolbar actions or buttons
- No changes to toolbar positioning (bottom on macOS)
- No iOS 26/macOS 26 Liquid Glass API adoption (separate contract)

### Compatibility Plan

- **Backward compatibility**: N/A (visual fixes only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits; no data changes

---

### Ownership

- **feature-owner**: All visual fixes - navigation bar, row backgrounds, sidebar material
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Details

#### Fix 1: Navigation Bar Background (MacContentView.swift)

Apply to the NavigationStack inside `sidebarNavigation`:

```swift
NavigationStack(path: pathBindingProvider(appState.router.selectedDestination)) {
  destinationRootView(for: appState.router.selectedDestination)
    .appDestinations()
}
.toolbar { ... }
#if os(macOS)
.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
#endif
// ... rest of modifiers
```

Note: `.toolbarBackgroundVisibility` for `.navigationBar` works differently than `.windowToolbar`. The `.navigationBar` target specifically affects the SwiftUI NavigationStack's internal bar rendering.

#### Fix 2: Navigation Tabs Row Background (UnifiedSidebar.swift)

Add the missing modifier to the navigation tabs Section:

```swift
// Navigation tabs section
Section {
  ForEach(AppTab.sidebarTabs) { tab in
    SidebarMenuRow(
      tab: tab,
      itemCount: tabCounts[tab] ?? 0,
      overdueCount: tab == .workspace ? overdueCount : 0
    )
    .tag(SidebarDestination.tab(tab))
  }
}
.listRowBackground(Color.clear)  // ADD THIS LINE
.accessibilityElement(children: .contain)
.accessibilityLabel("Navigation")
```

#### Fix 3: Native Sidebar Styling (UnifiedSidebar.swift + ResizableSidebar.swift)

**UnifiedSidebar.swift** - Make `.scrollContentBackground(.hidden)` conditional:

```swift
.listStyle(.sidebar)
#if os(iOS)
.scrollContentBackground(.hidden)
// iOS needs explicit material because NavigationSplitView doesn't provide it
.background {
  Rectangle()
    .fill(.thinMaterial)
    .ignoresSafeArea(.all, edges: .all)
}
#endif
// macOS: Let .listStyle(.sidebar) provide native translucent background
// The container (ResizableSidebar) provides the glass effect
```

**ResizableSidebar.swift** - Evaluate if `.glassSidebarBackground()` is still needed:

If we trust native `.listStyle(.sidebar)`:
- Option: Remove `.glassSidebarBackground()` from SidebarContainerView
- Or: Keep it for consistent glass effect but ensure no double-layering

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

**Required Queries** (feature-owner MUST execute at PATCHSET 1):

1. SwiftUI: "toolbarBackgroundVisibility navigationBar macOS SwiftUI"
2. SwiftUI: "listStyle sidebar native background macOS scrollContentBackground"
3. SwiftUI: "listRowBackground clear transparent List section"

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (`/websites/developer_apple_swiftui`)

| Query | Pattern Used |
|-------|--------------|
| toolbarBackgroundVisibility navigationBar macOS hide navigation bar background | Initial query - learned `.navigationBar` is iOS-only |
| listRowBackground clear transparent List section row background color | `.listRowBackground(Color.clear)` on navigation tabs Section |
| listStyle sidebar scrollContentBackground hidden native background macOS | Conditional `#if os(iOS)` for `.scrollContentBackground(.hidden)` - let macOS use native sidebar styling |
| ToolbarPlacement macOS available placements windowToolbar title | macOS uses `.windowToolbar` not `.navigationBar` |
| toolbarBackground hidden visibility modifier difference macOS | `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` hides background while keeping items |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 15:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Fixes are minimal, correct, and platform-native:**

1. **Navigation bar fix** (MacContentView.swift:162): `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` on NavigationStack correctly hides the toolbar background. Back button and overflow menu render on glass.

2. **Row backgrounds fix** (UnifiedSidebar.swift:80): Navigation tabs Section now has `.listRowBackground(Color.clear)` matching stage cards. Both sections transparent.

3. **Native sidebar styling** (UnifiedSidebar.swift:85-104): `.scrollContentBackground(.hidden)` is now iOS-only. macOS trusts native `.listStyle(.sidebar)` for Xcode-like translucent appearance. Material comes from ResizableSidebar container.

**Why SHIP YES:**
- Surgical fixes (3 modifier changes)
- Removes visual fighting between custom materials and native components
- Follows same pattern as Xcode, Finder, and other Apple apps
- No new complexity, no scope creep
- Existing DS tokens and a11y labels preserved

---

### Testing Checklist

| Test | Platform | Expected Outcome |
|------|----------|------------------|
| Navigate to PropertyDetailView | macOS | No dark navigation bar; back button visible on glass/transparent background |
| Navigate to ListingDetailView | macOS | No dark navigation bar; toolbar items visible on glass/transparent background |
| View sidebar in light mode | macOS | Translucent sidebar with clear row backgrounds; system selection highlighting |
| View sidebar in dark mode | macOS | Translucent sidebar with clear row backgrounds; system selection highlighting |
| Expand/collapse sidebar | macOS | Animations work correctly; no visual glitches |
| View sidebar | iPad | Translucent sidebar; navigation rows have clear backgrounds |

---

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| Removing `.scrollContentBackground(.hidden)` may affect iPad | Use `#if os(macOS)` / `#if os(iOS)` guards |
| Native sidebar styling may differ between macOS versions | Test on macOS 15.0 (deployment target) |
| Navigation bar fix may not apply to all detail views | Apply modifier at NavigationStack level, not individual views |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
