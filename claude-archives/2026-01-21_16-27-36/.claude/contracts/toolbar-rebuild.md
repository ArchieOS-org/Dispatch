## Interface Lock

**Feature**: Complete Toolbar/Titlebar Destruction and Rebuild
**Created**: 2026-01-20
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5) - All navigation/toolbar UI across 3 platforms
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - Touching all platform content views
- [x] **Unfamiliar area** (adds dispatch-explorer) - MUST be thorough about existing implementations

### Patchset Plan

Based on checked indicators (Complex UI + High-risk + Unfamiliar):

| Patchset | Gate | Agents |
|----------|------|--------|
| 0 | Exploration complete (VERY THOROUGH) | dispatch-explorer (MUST run first) |
| 1 | Compiles (delete all old, scaffold new) | feature-owner |
| 2 | Tests pass, new implementations work | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Cross-platform validation | xcode-pilot |

---

### CRITICAL CONTEXT: Previous Attempt Failed

The previous contract (`.claude/contracts/sidebar-simplify.md`) attempted incremental simplification. **This failed.**

**Why it failed:**
- Tried to "simplify" existing code instead of replacing it
- Created SimplifiedToolbar.swift and SimplifiedSidebar.swift as wrappers
- Left complexity scattered across multiple layers
- Did not fully remove old patterns

**This attempt is different:**
- COMPLETE DESTRUCTION of all existing toolbar/titlebar code
- REBUILD from scratch using iOS/iPadOS/macOS 26 native patterns
- NO preservation of existing implementations
- NO incremental refactoring

---

### Exploration Requirements (PATCHSET 0) - VERY THOROUGH

**dispatch-explorer MUST find and document ALL of the following before feature-owner begins:**

#### 1. Top Toolbar Code
- [ ] Native `.toolbar` usage across ALL views
- [ ] Custom toolbar implementations
- [ ] ToolbarItemGroup placements
- [ ] Toolbar view modifiers

#### 2. Bottom Toolbar Code
- [ ] SimplifiedToolbar.swift (from previous attempt)
- [ ] MacFloatingToolbar (inside SimplifiedToolbar.swift)
- [ ] Any floating toolbar overlays
- [ ] ToolbarIconButton.swift usage

#### 3. Title Bar Customization (macOS)
- [ ] WindowChromeConfigurator in MacContentView.swift
- [ ] titleVisibility settings
- [ ] titlebarAppearsTransparent settings
- [ ] toolbar?.showsBaselineSeparator settings
- [ ] isMovableByWindowBackground settings
- [ ] WindowUIState overlay handling

#### 4. Content Views (ALL platforms)
- [ ] ContentView.swift - root coordinator
- [ ] MacContentView.swift - macOS navigation
- [ ] iPadContentView.swift - iPad navigation
- [ ] iPhoneContentView.swift - iPhone navigation
- [ ] WindowContentView.swift (if exists)

#### 5. Design System References
- [ ] DESIGN_SYSTEM.md toolbar/sidebar sections
- [ ] DS.Spacing.bottomToolbarHeight
- [ ] DS.Spacing.bottomToolbarPadding
- [ ] DS.Spacing.bottomToolbarButtonSize
- [ ] DS.Spacing.bottomToolbarIconSize
- [ ] glassFloatingToolbarBackground() modifier

#### 6. Navigation Infrastructure
- [ ] SimplifiedSidebar.swift (from previous attempt)
- [ ] SidebarSelectionBinding.swift
- [ ] AppRouter.swift navigation paths
- [ ] DispatchCommands.swift keyboard shortcuts

#### 7. Supporting Components
- [ ] FilterMenu.swift (used in toolbars)
- [ ] GlobalFloatingButtons.swift (iPhone FAB)
- [ ] FloatingActionButton (iPad FAB)
- [ ] NavigationPopover (macOS search)

#### 8. State Management
- [ ] WindowUIState.swift (macOS per-window state)
- [ ] AppState.OverlayState
- [ ] AppOverlayState (iOS)
- [ ] Sheet state handling per platform

---

### Files to Destroy (Complete Deletion)

| File | Reason |
|------|--------|
| `Dispatch/Features/Navigation/SimplifiedToolbar.swift` | Previous attempt, replace completely |
| `Dispatch/Features/Navigation/SimplifiedSidebar.swift` | Previous attempt, replace completely |
| `Dispatch/Features/Navigation/SidebarSelectionBinding.swift` | Move logic into AppRouter, delete file |
| `Dispatch/Foundation/Platform/macOS/ToolbarIconButton.swift` | Old toolbar pattern, rebuild |

### Files to Heavily Modify (Near-Complete Rewrite)

| File | Changes |
|------|---------|
| `Dispatch/App/Platform/MacContentView.swift` | Strip to ~100 LOC, remove all toolbar/chrome code |
| `Dispatch/App/Platform/iPadContentView.swift` | Strip to ~60 LOC, use native patterns |
| `Dispatch/App/Platform/iPhoneContentView.swift` | Simplify, standardize toolbar approach |
| `Dispatch/App/ContentView.swift` | Simplify root coordinator |
| `Dispatch/Foundation/Platform/macOS/WindowUIState.swift` | Evaluate if still needed |

### Files to Create (New Architecture)

| File | Purpose | Target LOC |
|------|---------|------------|
| TBD after exploration | Platform-native toolbar | ~50 each |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: TBD (likely simplified toolbar state)
- Migration required: N

### Acceptance Criteria (3 max)

1. **Native patterns only**: All toolbar/titlebar code uses iOS/iPadOS/macOS 26 native `.toolbar` and window APIs - NO custom floating overlays on macOS
2. **Radical simplification**: Total lines of code for toolbar/navigation components reduced by 60%+ from current (~1200 LOC to ~480 LOC target)
3. **Cross-platform consistency**: Same visual hierarchy and interaction patterns across all three platforms with platform-appropriate implementations

### Non-goals (prevents scope creep)

- No new toolbar features or functionality (pure rebuild)
- No changes to search functionality (only how it's triggered)
- No backend/sync changes
- No sidebar content changes (only container/structure)
- No changes to sheet content (only presentation)

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only rebuild)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert entire branch; old implementation in git history

---

### Ownership

- **dispatch-explorer**: VERY THOROUGH exploration of ALL toolbar/titlebar/content view components (MUST complete before feature-owner starts)
- **feature-owner**: Complete destruction and rebuild using native patterns
- **data-integrity**: Not needed
- **jobs-critic**: Design bar enforcement for new toolbar UI
- **ui-polish**: Final refinements after SHIP YES
- **xcode-pilot**: Cross-platform validation

---

### Context7 Queries

**CRITICAL**: iOS/iPadOS/macOS 26 are beyond training data. Context7 is MANDATORY.

| Topic | Why Context7 Required |
|-------|----------------------|
| `.toolbar` placement options | macOS 26 may have new placement options |
| `.toolbarBackground` | Visibility and styling APIs |
| `.windowToolbar` vs `.automatic` | macOS titlebar integration |
| Window scene APIs | macOS 26 window chrome patterns |
| NavigationSplitView toolbar | How toolbars interact with split view |
| ToolbarItemGroup | Grouping and spacing patterns |

Log all Context7 lookups here:

(To be filled by feature-owner during PATCHSET 1)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| toolbar placement options primaryAction bottomBar windowToolbar NavigationSplitView macOS iOS | `.primaryAction` for macOS toolbar, `.bottomBar` for iOS |
| NavigationSplitView toolbar sidebar detail content toolbarBackground visibility | `NavigationSplitViewVisibility` binding for column control |
| ToolbarItemGroup placement primaryAction secondaryAction automatic | `ToolbarItemGroup(placement: .primaryAction)` for main toolbar actions |

CONTEXT7_QUERY: toolbar placement options primaryAction bottomBar windowToolbar NavigationSplitView macOS iOS
CONTEXT7_TAKEAWAYS:
- Use `.bottomBar` placement for iOS/iPadOS bottom toolbar
- Use `.primaryAction` placement for primary actions in toolbar
- Use `.automatic` placement when system should determine optimal placement
- NavigationSplitView with columnVisibility binding controls sidebar visibility
CONTEXT7_APPLIED:
- `.primaryAction` placement -> MacContentView.swift:48
- `.bottomBar` placement -> iPadContentView.swift:38
- `NavigationSplitViewVisibility` binding -> both content views

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: PENDING
**Reviewed**: PENDING

#### Checklist

- [ ] Ruthless simplicity - nothing can be removed without losing meaning
- [ ] One clear primary action per screen/state
- [ ] Strong hierarchy - headline -> primary -> secondary
- [ ] No clutter - whitespace is a feature
- [ ] Native feel - follows platform conventions

#### Verdict Notes

[jobs-critic writes specific feedback here after PATCHSET 2]

---

### Implementation Philosophy

#### What "Native" Means

**macOS:**
- Use `.toolbar` with `.windowToolbar` placement
- Titlebar should use system appearance (not transparent hacks)
- Sidebar toggle via `NavigationSplitView` visibility binding
- Search via toolbar item, not floating overlay

**iPad:**
- Use `.toolbar` with appropriate placements
- FAB if needed, but consider `.toolbar(.bottomBar)` instead
- Consistent with iOS HIG

**iPhone:**
- Use `.toolbar(.bottomBar)` for bottom actions
- Standard navigation bar for top
- FAB only if truly needed (evaluate)

#### What We're Eliminating

1. **WindowChromeConfigurator** - Let system handle window chrome
2. **MacFloatingToolbar** - Use native `.toolbar` instead
3. **ToolbarIconButton** - Use standard Button in toolbar
4. **Custom overlay-based toolbars** - Use native placements
5. **Duplicate state (WindowUIState + AppState)** - Consolidate

---

### Exploration Complete (PATCHSET 0) ✅

**Status**: COMPLETE
**Date**: 2026-01-20

#### Critical Finding: Previous Attempt Created Wrapper Complexity

The "SimplifiedToolbar" and "SimplifiedSidebar" are NOT simple:
- SimplifiedToolbar.swift: **343 LOC** (target was ~100)
- SimplifiedSidebar.swift: **101 LOC** (target was ~80)
- Still uses custom MacFloatingToolbar overlay
- References UNDEFINED modifiers (`.glassFloatingToolbarBackground()`)
- Did NOT eliminate complexity, just moved it

#### Files to DESTROY (Delete Entirely)

| File | LOC | Why Delete |
|------|-----|------------|
| `Dispatch/Features/Navigation/SimplifiedToolbar.swift` | 343 | Too complex, uses custom overlays |
| `Dispatch/Features/Navigation/SimplifiedSidebar.swift` | 101 | Wrapper on wrapper |
| `Dispatch/Features/Navigation/SidebarSelectionBinding.swift` | 54 | Inline this into AppRouter |
| `Dispatch/Foundation/Platform/macOS/ToolbarIconButton.swift` | 73 | Use native Button |
| `Dispatch/Features/Navigation/` (directory) | — | Delete entire directory |

#### Files to COMPLETELY REWRITE

| File | Current LOC | Target LOC | Approach |
|------|-------------|------------|----------|
| `MacContentView.swift` | 297 | ~80 | Native `.toolbar`, NO overlays |
| `iPadContentView.swift` | 101 | ~50 | Native `.toolbar`, NO custom sidebars |
| `ContentView.swift` | 340 | ~100 | Simpler platform dispatch |

#### Files to REMOVE (Already Deleted in Branch)

- BottomToolbar.swift (470 LOC) ✓
- SidebarState.swift (~30 LOC) ✓
- TitleDropdownButton.swift (~50 LOC) ✓

#### UNDEFINED Modifiers (Critical Bug)

```swift
// These are called but DON'T EXIST:
.glassFloatingToolbarBackground()  // SimplifiedToolbar.swift:179
.glassCircleBackground()           // GlassButton.swift:29
```

**Solution**: Don't use these. Use native `.regularMaterial` instead.

#### Design System Tokens Referenced

```swift
DS.Spacing.bottomToolbarHeight      // Used by FilterMenu, ToolbarIconButton
DS.Spacing.bottomToolbarButtonSize  // 36pt
DS.Spacing.bottomToolbarIconSize    // 17pt
DS.Spacing.bottomToolbarPadding
DS.Spacing.sidebarDefaultWidth      // 240pt
DS.Spacing.sidebarMinWidth
DS.Spacing.sidebarMaxWidth
```

#### What "Native" Means (Implementation Guide)

**macOS 26:**
```swift
.toolbar {
  ToolbarItemGroup(placement: .primaryAction) { /* main actions */ }
  ToolbarItem(placement: .secondaryAction) { /* overflow */ }
}
// Sidebar via NavigationSplitView - extends under toolbar automatically
// NO WindowChromeConfigurator - let system handle titlebar
```

**iPadOS 26:**
```swift
.toolbar {
  ToolbarItemGroup(placement: .bottomBar) { /* bottom actions */ }
}
// Or inline floating button if truly needed
```

**iOS 26:**
```swift
.toolbar {
  ToolbarItemGroup(placement: .bottomBar) { /* bottom actions */ }
}
// Standard navigation bar for top
```

#### Architecture After Rebuild

```
ContentView (Root - ~100 LOC)
├── NavigationSplitView (native, no wrapper)
│   ├── sidebar: UnifiedSidebarContent (existing, keep)
│   └── detail: NavigationStack
├── .toolbar { /* native toolbar items */ }
└── Platform adaptations via #if os()
```

**NO**:
- Custom floating toolbars
- WindowChromeConfigurator
- Wrapper views (SimplifiedSidebar, SimplifiedToolbar)
- Undefined glass modifiers

#### LOC Reduction Target

| Before | After | Reduction |
|--------|-------|-----------|
| ~1200 LOC | ~400 LOC | **67%** |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
- **dispatch-explorer MUST complete PATCHSET 0 before feature-owner begins PATCHSET 1**
- **This is a DESTRUCTION and REBUILD, not an incremental refactor**
