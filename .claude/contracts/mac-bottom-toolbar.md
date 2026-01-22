## Interface Lock

**Feature**: DIS-78: Mac Bottom Toolbar (Add/Filter/Search)
**Created**: 2026-01-22
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

### Acceptance Criteria (3 max)

1. macOS shows a bottom toolbar with Add button and Filter button (grouped, left side) and Search button (right side)
2. Bottom toolbar matches the style of the existing top toolbar (same look, hover states, `.thinMaterial` background)
3. Add, Filter, and Search buttons are removed from top toolbar on macOS (moved to bottom toolbar)

### Non-goals (prevents scope creep)

- No changes to iOS or iPadOS UI (this is macOS-only)
- No changes to button functionality (only relocation)
- No changes to the keyboard shortcuts (Cmd+N, Cmd+F remain)
- No new window button relocation (stays in top toolbar if present)

### Compatibility Plan

- **Backward compatibility**: N/A - UI-only change
- **Default when missing**: N/A
- **Rollback strategy**: Revert PR to restore top toolbar buttons

---

### Implementation Notes

#### Current State (MacContentView.swift lines 51-72)

The existing top toolbar in `MacContentView.swift` contains:
- `FilterMenu` (audience filter with tap-to-cycle and menu)
- Add button (`Image(systemName: "plus")`)
- New Window button (conditional, `Image(systemName: "square.on.square")`)
- Search button (`Image(systemName: "magnifyingglass")`)

#### Target Architecture

1. **Create `MacBottomToolbar.swift`** in `Dispatch/App/Platform/`
   - New view component for macOS bottom toolbar
   - Uses `DS.Spacing.bottomToolbar*` tokens (already defined in DSSpacing.swift)
   - Left group: Add button + FilterMenu (horizontal stack, no spacing between)
   - Right side: Search button
   - Background: `.thinMaterial` to match top toolbar aesthetic
   - Hover states: Match existing `AudienceFilterButton` pattern (`.onHover` with background fill)

2. **Modify `MacContentView.swift`**
   - Remove FilterMenu, Add button, and Search button from `.toolbar {}` block
   - Keep New Window button in top toolbar (if present)
   - Add bottom toolbar as `.safeAreaInset(edge: .bottom)` or overlay

#### Design System Tokens (Pre-existing)

From `DSSpacing.swift`:
- `DS.Spacing.bottomToolbarHeight: 44`
- `DS.Spacing.bottomToolbarButtonSize: 36`
- `DS.Spacing.bottomToolbarIconSize: 18`
- `DS.Spacing.bottomToolbarPadding: 12`

#### Reference Components

- `AudienceFilterButton.swift` - Hover state pattern for macOS
- `FilterMenu.swift` - Current filter menu implementation with split control
- Preview in FilterMenu.swift "In Toolbar Context" shows the target layout

#### Context7 Queries to Perform

- SwiftUI: `safeAreaInset` vs overlay for bottom toolbar placement
- SwiftUI: macOS toolbar styling best practices

---

### Ownership

- **feature-owner**: Create MacBottomToolbar component, refactor MacContentView to use it
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: safeAreaInset edge bottom macOS toolbar placement view modifier
CONTEXT7_TAKEAWAYS:
- `safeAreaInset(edge:alignment:spacing:content:)` is the correct modifier for placing content at edges
- It automatically adjusts the safe area and insets the modified view
- For vertical edges, use `VerticalEdge.bottom` with `.bottom`
- `spacing: 0` removes default spacing between content and inset view
CONTEXT7_APPLIED:
- `.safeAreaInset(edge: .bottom, spacing: 0)` -> MacContentView.swift:62

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| safeAreaInset edge bottom macOS toolbar placement | `.safeAreaInset(edge: .bottom, spacing: 0)` with content closure |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 (jobs-critic)

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The implementation is clean, native, and purposeful:

1. **Ruthless simplicity**: Three controls only (Add, Filter, Search). No excess UI.

2. **Clear hierarchy**: Add button positioned first (leftmost), Filter secondary, Search as utility on right. Left-to-right reading order matches workflow.

3. **Native macOS feel**:
   - `.thinMaterial` background matches existing top toolbar
   - Hover states use `Color.primary.opacity(0.08)` matching AudienceFilterButton pattern
   - `.safeAreaInset(edge: .bottom, spacing: 0)` is correct SwiftUI pattern
   - Keyboard shortcuts preserved (Cmd+N, Cmd+F)

4. **Design system compliance**: All values from DS.Spacing.bottomToolbar* tokens, @ScaledMetric for Dynamic Type

5. **Accessibility**: VoiceOver labels + hints, .help() tooltips, keyboard shortcuts

Minor observation (not a blocker): FilterMenu buttons lack hover states while Add/Search have them. This matches the existing FilterMenu component behavior and could be addressed in a future polish pass if desired.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
