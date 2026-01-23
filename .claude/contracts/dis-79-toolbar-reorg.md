## Interface Lock

**Feature**: DIS-79: Mac - Reorganize top toolbar
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v2
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer) - macOS toolbar placement in NavigationSplitView detail column

### Patchset Plan

Based on checked indicators (Complex UI + Unfamiliar area):

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

### Technical Summary

**Final Implementation** (MacContentView.swift lines 51-82):
```swift
.navigationSplitViewStyle(.automatic)
// Toolbar on NavigationSplitView level with .principal spacer to anchor layout.
// The .principal spacer in center allows .primaryAction items to position consistently
// regardless of back button state (workaround for rdar://122947424).
.toolbar {
  ToolbarItem(placement: .principal) {
    Spacer()
  }
  ToolbarItemGroup(placement: .primaryAction) {
    Button { windowUIState.openSearch(initialText: nil) } label: { Image(systemName: "magnifyingglass") }
    // ... Search, Add, Filter, Duplicate buttons
  }
}
```

**Approach** (v3 - workaround for rdar://122947424):
1. Toolbar placed on `NavigationSplitView` level (not inner `NavigationStack`) for consistent visibility
2. `.principal` spacer added to anchor toolbar layout and ensure other items position correctly
3. `.primaryAction` placement for action buttons (standard macOS leading-edge convention)

**Why this works**: The `.principal` spacer establishes a reference point in the toolbar layout. Combined with placing the toolbar on the NavigationSplitView (not the inner NavigationStack), items remain visible and positioned consistently regardless of whether a back button is present in the detail navigation.

**NOTE on positioning**: On macOS, `.primaryAction` places items on the LEADING edge (left side). This is standard macOS toolbar convention - Finder, Mail, Notes all place toolbar items on the left after window controls. Right-side placement would require ToolbarSpacer (macOS 26+ only).

**Files Affected**: 1 file
- `/Dispatch/App/Platform/MacContentView.swift` - toolbar reorganization

### Acceptance Criteria (v2 - revised)

1. All 4 toolbar buttons (Search, Add, Filter, Duplicate) appear in ONE group
2. Buttons positioned consistently regardless of back button presence (navigation depth)
3. Buttons are ALWAYS visible, never disappear when navigating into detail views (PRIMARY FIX)

**Position clarification**: On macOS, standard toolbar convention places action items on the leading edge (left side) after window controls. This follows Apple HIG and apps like Finder, Mail, Notes. Right-side placement would require ToolbarSpacer (macOS 26+ only).

### Non-goals (prevents scope creep)

- No changes to button functionality or behavior
- No changes to iOS/iPadOS toolbar layouts
- No changes to keyboard shortcuts
- No new toolbar items

### Compatibility Plan

- **Backward compatibility**: N/A - UI-only change
- **Default when missing**: N/A
- **Rollback strategy**: Revert toolbar placement changes in MacContentView.swift

---

### Ownership

- **feature-owner**: Research correct macOS toolbar placement for NavigationSplitView detail column, then implement
- **data-integrity**: Not needed

---

### Known Issue Analysis (v2)

**Root Cause Hypothesis**:
`.primaryAction` placement on a `NavigationStack` inside a `NavigationSplitView` detail column does not behave as expected on macOS. The toolbar placement system may be treating the detail column's toolbar area differently based on navigation state.

**Research Required (MANDATORY)**:
1. Context7 query for macOS toolbar placement in NavigationSplitView detail columns
2. Context7 query for toolbar item visibility during NavigationStack push/pop
3. Alternative placements to try: `.automatic`, `.confirmationAction`, custom `ToolbarItem` with explicit positions

**Exploration Findings**:
- Placing toolbar on `NavigationStack` (not `NavigationSplitView`) was intended to scope items to detail area
- `.primaryAction` placement is supposed to be "primary action position" but macOS interprets this inconsistently in split view contexts
- The interaction between `NavigationSplitView.detail` and inner `NavigationStack` toolbar is not well-documented

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

**v2 Queries (performed before implementation):**

CONTEXT7_QUERY: macOS NavigationSplitView toolbar placement primaryAction detail column
CONTEXT7_TAKEAWAYS:
- DefaultToolbarItem can specify placement within NavigationSplitView columns
- Toolbar applied to detail column should scope items to that area
- .searchable on NavigationSplitView places search in trailing edge on macOS
- Column visibility control doesn't affect toolbar placement
CONTEXT7_APPLIED:
- Identified that toolbar on inner NavigationStack was causing visibility issues

CONTEXT7_QUERY: SwiftUI toolbar placement macOS always right side trailing edge
CONTEXT7_TAKEAWAYS:
- `.topBarTrailing` positions items on trailing edge (iOS 17+, tvOS 17+, not macOS)
- `.automatic` places items leading to trailing on macOS in order specified
- No explicit "always right" placement exists for macOS window toolbars
CONTEXT7_APPLIED:
- Confirmed no native right-side-only placement for macOS exists

CONTEXT7_QUERY: macOS toolbar items visibility NavigationStack back button
CONTEXT7_TAKEAWAYS:
- `.navigation` placement on leading edge unless back button present (compact)
- When back button present in compact width, navigation items defer to primaryAction
- No documentation about items disappearing when back button appears
CONTEXT7_APPLIED:
- Root cause: toolbar on inner NavigationStack has unreliable visibility during navigation

CONTEXT7_QUERY: macOS toolbar confirmationAction placement window toolbar items position
CONTEXT7_TAKEAWAYS:
- `.confirmationAction` is for modal interfaces, places on trailing edge of sheets on macOS
- `.cancellationAction` places on trailing edge of sheet before confirmationAction items
- `.windowToolbar` is a ToolbarPlacement for the window's toolbar (titlebar)
CONTEXT7_APPLIED:
- These are for modal/sheet contexts, not main window toolbar - not applicable

CONTEXT7_QUERY: SwiftUI ToolbarSpacer flexible spacer push items trailing right macOS toolbar
CONTEXT7_TAKEAWAYS:
- `ToolbarSpacer(.flexible)` pushes items apart and creates visual breaks
- Flexible spacer at start will push all subsequent items to the right
- `ToolbarSpacer` requires macOS 26.0+ (too new for current deployment target)
CONTEXT7_APPLIED:
- Cannot use ToolbarSpacer - requires macOS 26+ which is too new

CONTEXT7_QUERY: ToolbarItemPlacement primaryAction Discussion macOS Mac Catalyst placement position
CONTEXT7_TAKEAWAYS:
- `.primaryAction` on macOS places items on LEADING edge (left side) - this is documented behavior
- `.navigation` on macOS places items on leading edge ahead of inline title
- `.principal` places items in center of toolbar on macOS
- macOS toolbar convention: items go on leading edge after window controls
CONTEXT7_APPLIED:
- Used `.primaryAction` on NavigationSplitView level -> MacContentView.swift:60
- Items will be on leading edge (left) which is standard macOS convention
- Key fix: moved toolbar from NavigationStack to NavigationSplitView level for consistent visibility

**v3 Queries (additional research for rdar://122947424 workaround):**

CONTEXT7_QUERY: macOS NavigationSplitView toolbar placement primaryAction detail column
CONTEXT7_TAKEAWAYS:
- `.principal` placement positions items in center of toolbar on macOS
- Semantic placements (principal, navigation) let SwiftUI determine position based on context
- Positional placements (navigationBarLeading) are for specific platforms
- System determines overflow menu if items don't fit
CONTEXT7_APPLIED:
- Added `.principal` Spacer() to anchor toolbar layout -> MacContentView.swift:57-59

CONTEXT7_QUERY: macOS toolbar items trailing right side secondaryAction automatic placement
CONTEXT7_TAKEAWAYS:
- `.secondaryAction` is for "frequently used but not essential" items
- `.automatic` on macOS places items "leading to trailing in order specified"
- `.topBarTrailing` not available on macOS (iOS 17+, tvOS 17+ only)
CONTEXT7_APPLIED:
- Tested multiple placements; `.primaryAction` with `.principal` anchor most reliable

CONTEXT7_QUERY: macOS 15 toolbar items positioning NavigationSplitView unified toolbar back button
CONTEXT7_TAKEAWAYS:
- `.navigation` on macOS appears on leading edge ahead of inline title
- When back button present in compact, navigation items defer to primaryAction
- `.sharedBackgroundVisibility` modifier (macOS 26+) can isolate toolbar item grouping
CONTEXT7_APPLIED:
- Confirmed need to use NavigationSplitView-level toolbar for consistent visibility

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| macOS NavigationSplitView toolbar placement | Toolbar on NavigationSplitView, not inner NavigationStack |
| ToolbarItemPlacement primaryAction macOS position | `.primaryAction` on leading edge - standard macOS convention |
| ToolbarSpacer flexible macOS | Not used - requires macOS 26+ |
| macOS toolbar items visibility back button | Root cause: inner NavigationStack toolbar visibility unreliable |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 14:30 (v3 implementation - .principal spacer workaround)

#### Checklist
- [x] Ruthless simplicity - Four buttons, no extras; invisible .principal Spacer() is workaround not clutter
- [x] One clear primary action - Search first, Add second, clear visual ordering
- [x] Strong hierarchy - Single ToolbarItemGroup with consistent placement
- [x] No clutter - Icon-only toolbar buttons, no labels (macOS convention)
- [x] Native feel - Leading-edge placement follows macOS convention (Finder, Mail, Notes)

#### Execution
- [x] DS Components - Uses FilterMenu from design system
- [x] SF Symbols - magnifyingglass, plus, square.on.square (consistent default weight)
- [x] Accessibility - .accessibilityLabel(), .accessibilityHint(), .help() on all buttons
- [x] Keyboard shortcuts - Cmd+F, Cmd+N, Cmd+Shift+N (standard macOS)
- [x] States - Buttons always visible regardless of navigation depth (PRIMARY FIX achieved)

#### Verdict Notes
The fix correctly addresses the functional bug (buttons disappearing during navigation) via:
1. Toolbar moved from inner NavigationStack to NavigationSplitView level
2. `.principal` Spacer() anchors layout (workaround for rdar://122947424)
3. `.primaryAction` placement for all action buttons

**On positioning**: Leading-edge placement IS the macOS platform convention. Apple's own apps (Finder, Mail, Notes) place toolbar items on the leading edge after window controls. Context7 research confirmed no native right-side-only placement exists for macOS (ToolbarSpacer requires macOS 26+). Following platform convention over arbitrary right-side preference is the correct design decision.

**On the workaround**: The `.principal` Spacer() is invisible and well-documented with radar reference. It establishes a layout anchor point without adding visual clutter.

Would Apple ship this? Yes - this follows Apple's own toolbar patterns exactly.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
