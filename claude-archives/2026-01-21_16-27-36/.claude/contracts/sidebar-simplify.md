## Interface Lock

**Feature**: Sidebar/Toolbar Simplification Refactor
**Created**: 2026-01-20
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - Major navigation rebuild
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (Complex UI + High-risk + Unfamiliar):

| Patchset | Gate | Agents |
|----------|------|--------|
| 0 | Exploration complete | dispatch-explorer (MUST run first) |
| 1 | Compiles (scaffold new structure) | feature-owner |
| 2 | Tests pass, old components removed | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Cross-platform validation | xcode-pilot |

---

### Exploration Complete (PATCHSET 0) ✅

**dispatch-explorer completed 2026-01-20**

#### Current Architecture

```
ContentView (Root Coordinator)
├── #if os(macOS)
│   └── MacContentView (480 LOC) - NavigationSplitView + BottomToolbar
│       ├── UnifiedSidebarContent (shared)
│       ├── NavigationStack (per-destination)
│       └── BottomToolbar (470 LOC) - Things 3-style floating
│
├── #else (iOS)
│   ├── iPad → iPadContentView - NavigationSplitView
│   │   └── UnifiedSidebarContent (shared with macOS)
│   └── iPhone → iPhoneContentView - Single NavigationStack
│       └── MenuPageView (Things 3-style menu)
```

#### File Inventory

| File | LOC | Action | Notes |
|------|-----|--------|-------|
| `BottomToolbar.swift` | 470 | REBUILD | Highest complexity, context-driven buttons |
| `MacContentView.swift` | 480 | REBUILD | Too much responsibility, overlay/toolbar/sidebar |
| `iPadContentView.swift` | ~200 | SIMPLIFY | Duplicates sidebar binding logic |
| `AppRouter.swift` | 196 | SIMPLIFY | Dual path systems (Mac/iPad vs iPhone) |
| `WindowUIState.swift` | 110 | CONSOLIDATE | Duplicates OverlayState from AppState |
| `TitleDropdownButton.swift` | ~50 | DELETE | Marked unused |
| `SidebarState.swift` | ~30 | DELETE | Deprecated, move Notification.Name only |
| `UnifiedSidebarContent.swift` | 140 | KEEP | Already well-designed, shared component |
| `SidebarMenuRow.swift` | 69 | KEEP | Already unified |

#### Complexity Hotspots

1. **BottomToolbar.swift** (470 LOC)
   - Context-driven button layout
   - Multiple optional closures
   - 20+ preview variants (100+ lines of preview code)

2. **MacContentView.swift** (480 LOC)
   - Sidebar + detail + overlay + toolbar + keyboard + window chrome
   - Should be decomposed into smaller focused views

3. **Overlay State Duplication**
   - `AppState.OverlayState` AND `WindowUIState.OverlayState` (redundant)

4. **Sidebar Selection Binding**
   - Identical binding code in MacContentView AND iPadContentView

#### Key Simplification Opportunities

1. **Delete deprecated**: TitleDropdownButton, SidebarState
2. **Consolidate overlay state**: Single definition, not two
3. **Extract sidebar binding**: Shared function in AppRouter
4. **Decompose MacContentView**: Separate concerns
5. **Simplify BottomToolbar**: Extract context logic, reduce previews

---

### Contract

- New/changed model fields: TBD after exploration (likely sidebar state simplification)
- DTO/API changes: None expected
- State/actions added: TBD (likely simplified sidebar/toolbar state)
- Migration required: N

### Acceptance Criteria (3 max)

1. **Unified sidebar implementation**: Single sidebar component works correctly on macOS, iOS, and iPadOS with platform-appropriate behavior (extends under toolbar on Mac/iPad)
2. **Radical simplification**: Total lines of code for sidebar/toolbar components reduced by 40%+ from current implementation
3. **Cross-platform builds**: App compiles and runs correctly on all three platforms (iOS 26, iPadOS 26, macOS 26)

### Non-goals (prevents scope creep)

- No new sidebar features or functionality (pure simplification)
- No changes to sidebar content/menu items (only structure)
- No backend/sync changes
- No changes to non-navigation UI components

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only refactor)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert; old implementation preserved in history

---

### Ownership

- **dispatch-explorer**: Full codebase exploration of toolbar/sidebar/titlebar components (MUST complete before feature-owner starts)
- **feature-owner**: End-to-end rebuild of sidebar/toolbar using modern SwiftUI patterns
- **data-integrity**: Not needed

---

### Context7 Queries

**CRITICAL**: macOS/iOS/iPadOS 26 are beyond training data. Context7 is mandatory for:

| Topic | Why Context7 Required |
|-------|----------------------|
| NavigationSplitView | New APIs in SwiftUI for iOS/macOS 26 |
| Toolbar placement | Platform-specific toolbar patterns may have changed |
| Sidebar styling | New modifiers for sidebar-under-toolbar behavior |
| WindowGroup/Scene | macOS 26 window management patterns |
| @Environment values | New environment values for navigation state |

Log all Context7 lookups here:

CONTEXT7_QUERY: NavigationSplitView columnVisibility sidebar detail prominentDetail iOS macOS
CONTEXT7_TAKEAWAYS:
- Use @State with NavigationSplitViewVisibility and pass $binding to init
- Visibility options: .all, .doubleColumn, .detailOnly, .automatic
- Split view ignores visibility control when collapsed into stack
- Two-column init: init(columnVisibility:preferredCompactColumn:sidebar:detail:)
CONTEXT7_APPLIED:
- NavigationSplitViewVisibility binding -> SimplifiedSidebar.swift:36

CONTEXT7_QUERY: toolbar placement bottomBar windowToolbar macOS iOS SwiftUI
CONTEXT7_TAKEAWAYS:
- .bottomBar placement available iOS 14+, iPadOS 14+, Mac Catalyst 14+
- .windowToolbar for macOS titlebar/toolbar area
- .bottomBar NOT available on macOS (use custom overlay instead)
CONTEXT7_APPLIED:
- Conditional #if os(iOS) for .bottomBar -> SimplifiedToolbar.swift:113-152
- Custom MacFloatingToolbar for macOS -> SimplifiedToolbar.swift:156-255

CONTEXT7_QUERY: toolbarBackgroundVisibility toolbarBackground hidden windowToolbar macOS sidebar
CONTEXT7_TAKEAWAYS:
- .toolbarBackgroundVisibility(.hidden, for: .windowToolbar) hides toolbar background
- Allows content to extend to window edge (sidebar-under-toolbar)
- Different from .toolbarVisibility which hides entire toolbar including traffic lights
CONTEXT7_APPLIED:
- .toolbarBackgroundVisibility(.hidden, for: .windowToolbar) -> SimplifiedSidebar.swift:55

CONTEXT7_QUERY: navigationSplitViewStyle balanced prominentDetail automatic
CONTEXT7_TAKEAWAYS:
- .balanced reduces detail size when showing leading columns
- .prominentDetail maintains detail size when hiding/showing columns
- .automatic resolves based on context
CONTEXT7_APPLIED:
- .navigationSplitViewStyle(.balanced) -> SimplifiedSidebar.swift:52

CONTEXT7_QUERY: @Observable macro state management environment SwiftUI
CONTEXT7_TAKEAWAYS:
- Use @State (not @StateObject) for @Observable instances at app level
- Use .environment(_:) instead of .environmentObject(_:)
- Access via @Environment(Type.self) in child views
CONTEXT7_APPLIED:
- Existing WindowUIState already uses @Observable correctly (validated pattern)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| NavigationSplitView columnVisibility | @State + $binding to init, .all/.detailOnly visibility |
| toolbar placement bottomBar windowToolbar | .bottomBar on iOS, custom overlay on macOS |
| toolbarBackgroundVisibility hidden windowToolbar | .toolbarBackgroundVisibility(.hidden, for: .windowToolbar) for sidebar-under-toolbar |
| navigationSplitViewStyle balanced prominentDetail | .balanced style for responsive layout |
| @Observable state management | @State + .environment(_:) pattern (validated existing code) |

**Note**: All 5 required Context7 queries completed. Patterns verified and applied.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-20

#### Checklist

- [x] Ruthless simplicity - 68% code reduction, native patterns replace custom chrome, nothing left to remove
- [x] One clear primary action per screen/state - Plus button (macOS) / FAB (iPad) unmistakably primary
- [x] Strong hierarchy - Filter (contextual) < Plus (primary) < Search (secondary), FAB elevated above content
- [x] No clutter - 4 toolbar buttons on macOS, 1 FAB + 1 filter on iPad, generous whitespace
- [x] Native feel - .toolbar with .primaryAction/.bottomBar, NavigationSplitView, keyboard shortcuts, HIG-compliant

#### Verdict Notes

**Strengths:**
- Destroyed 1,082 LOC of custom chrome (BottomToolbar, WindowChromeConfigurator, wrappers)
- Rebuilt with 14 lines of native `.toolbar` on macOS, 5 lines on iPad
- Uses DS tokens consistently (DS.Spacing, DS.Colors, DS.Shadows)
- Accessibility: identifiers, labels, and values present on all interactive elements
- Keyboard shortcuts follow macOS conventions (Cmd+N, Cmd+Shift+N, Cmd+F)

**What remains is structural, not decorative.** The code is now what Apple intended when they designed NavigationSplitView and `.toolbar`.

**Minor observations (NOT blocking):**
1. `quickFindOverlay` uses hardcoded values instead of DS tokens - but this was not in rebuild scope
2. FilterMenu has 119 lines of preview code - acceptable for development, could trim later

**Would Apple ship this?** Yes.

---

### Implementation Plan (Tear-Down & Rebuild)

#### Target Architecture (RADICAL SIMPLIFICATION)

```
ContentView (Root - minimal)
├── NavigationSplitView (unified for Mac/iPad)
│   ├── Sidebar (extends under toolbar)
│   │   └── SidebarContent (unified, ~100 LOC target)
│   └── Detail
│       └── NavigationStack
└── iPhone: TabView or single NavigationStack
    └── MenuView (simplified)
```

**Goal**: Reduce total navigation code from ~1500+ LOC to ~500 LOC

---

#### PATCHSET 1: Scaffold New Architecture (Compiles)

**Create new simplified components:**

1. **`SimplifiedSidebar.swift`** (~80 LOC target)
   - Single component for Mac + iPad
   - Uses `NavigationSplitView` with `.prominentDetail`
   - Sidebar extends under toolbar via `.toolbarBackground(.hidden, for: .windowToolbar)`
   - Query Context7 for iOS/macOS 26 NavigationSplitView patterns

2. **`SimplifiedToolbar.swift`** (~100 LOC target)
   - Replaces 470 LOC BottomToolbar
   - Uses native `.toolbar` with conditional content
   - Platform-appropriate placement (bottom on Mac, top on iOS)

3. **State consolidation in `AppRouter`**
   - Move sidebar selection binding to AppRouter extension
   - Remove WindowUIState.OverlayState (use AppState.OverlayState only)

**DO NOT delete old files yet** - compile verification only

---

#### PATCHSET 2: Wire Up & Delete Old Code (Tests Pass)

**Replace old with new:**

1. Update `ContentView.swift` to use new components
2. Update `MacContentView.swift` → use SimplifiedSidebar
3. Update `iPadContentView.swift` → use SimplifiedSidebar
4. Delete deprecated files:
   - `TitleDropdownButton.swift`
   - `SidebarState.swift` (move Notification.Name first)
5. Remove redundant code from `WindowUIState.swift`

**Verify:**
- All tests pass
- Sidebar extends under toolbar on Mac/iPad
- Navigation works correctly on all platforms

---

#### PATCHSET 2.5: Design Bar Review

**jobs-critic evaluates:**
- Is there ANYTHING we can remove?
- One clear primary action per state?
- Native platform feel?
- Simpler than before?

**ui-polish addresses:** Any refinements from critique

---

#### PATCHSET 3: Cross-Platform Validation

**xcode-pilot validates on:**
- iOS 26 Simulator (iPhone)
- iPadOS 26 Simulator (iPad)
- macOS 26 (build only, no launch per rules)

**Verify:**
- Sidebar-under-toolbar behavior (Mac/iPad)
- Correct navigation on all platforms
- No regressions

---

#### Context7 Required Queries

| Query | Why |
|-------|-----|
| `NavigationSplitView columnVisibility iOS 26` | API may have changed |
| `toolbar placement macOS SwiftUI` | Bottom toolbar patterns |
| `toolbarBackground hidden windowToolbar` | Sidebar-under-toolbar |
| `NavigationSplitView prominentDetail` | Sidebar width behavior |
| `@Observable navigation state SwiftUI` | Modern state patterns |

---

#### Files to Create

| File | Purpose | Target LOC |
|------|---------|------------|
| `SimplifiedSidebar.swift` | Unified sidebar for Mac/iPad | ~80 |
| `SimplifiedToolbar.swift` | Replaces BottomToolbar | ~100 |

#### Files to Delete

| File | Reason |
|------|--------|
| `TitleDropdownButton.swift` | Unused |
| `SidebarState.swift` | Deprecated (after moving Notification.Name) |

#### Files to Heavily Modify

| File | Changes |
|------|---------|
| `MacContentView.swift` | Strip down to ~150 LOC, use SimplifiedSidebar |
| `iPadContentView.swift` | Strip down to ~100 LOC, use SimplifiedSidebar |
| `BottomToolbar.swift` | Replace with SimplifiedToolbar OR delete |
| `WindowUIState.swift` | Remove OverlayState duplication |
| `AppRouter.swift` | Add shared sidebar binding extension |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
- **dispatch-explorer MUST complete PATCHSET 0 before feature-owner begins PATCHSET 1**
