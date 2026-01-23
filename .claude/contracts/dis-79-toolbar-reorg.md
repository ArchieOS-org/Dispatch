## Interface Lock

**Feature**: DIS-79: Mac - Reorganize top toolbar
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

Based on checked indicators (Complex UI only):

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

**Current State** (MacContentView.swift lines 52-72):
```swift
.toolbar {
  ToolbarItemGroup(placement: .primaryAction) {
    FilterMenu(audience: $appState.lensState.audience)
    Button { handleNew() } label: { Image(systemName: "plus") }
    if supportsMultipleWindows {
      Button { openWindow(id: "main") } label: { Image(systemName: "square.on.square") }
    }
    Button { windowUIState.openSearch(initialText: nil) } label: { Image(systemName: "magnifyingglass") }
  }
}
```

**Target State**:
```swift
.toolbar {
  // Left side: Filter + Add as a grouped pair, separate from back button
  // Using .secondaryAction places items left of center but in their own visual group,
  // distinct from the system back button which appears in .navigation placement
  ToolbarItemGroup(placement: .secondaryAction) {
    FilterMenu(audience: $appState.lensState.audience)
    Button { handleNew() } label: { Image(systemName: "plus") }
  }

  // Right side: Search + Duplicate (duplicate on far right)
  ToolbarItemGroup(placement: .primaryAction) {
    Button { windowUIState.openSearch(initialText: nil) } label: { Image(systemName: "magnifyingglass") }
    if supportsMultipleWindows {
      Button { openWindow(id: "main") } label: { Image(systemName: "square.on.square") }
    }
  }
}
```

**Files Affected**: 1 file
- `/Dispatch/App/Platform/MacContentView.swift` - toolbar reorganization

### Acceptance Criteria (3 max)

1. Filter and Add buttons appear on the left side of the toolbar
2. Search and Duplicate buttons appear on the right side (Duplicate on far right)
3. When back button is visible in navigation, Filter/Add shift to its right (not displaced entirely)

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

- **feature-owner**: Reorganize toolbar in MacContentView.swift using ToolbarItemGroup placements
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: macOS toolbar ToolbarItemPlacement navigation cancellationAction automatic principal separate groups visual separation back button
CONTEXT7_TAKEAWAYS:
- `.navigation` placement positions items on leading edge, BUT groups them with system back button
- `ToolbarItemGroup` creates shared visual background (bubble) for all items within it
- Using different placements creates separate visual groups in macOS toolbars
- `.secondaryAction` is for items that are "frequently used but not essential for the current context"
- `.sharedBackgroundVisibility(.hidden)` can separate items but requires macOS 26.0+ (too new)
CONTEXT7_APPLIED:
- `.secondaryAction` for left side (Filter + Add) - separate visual group from back button -> MacContentView.swift:55-62
- `.primaryAction` for right side (Search + Duplicate) -> MacContentView.swift:65-78

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| macOS toolbar ToolbarItemPlacement navigation separate groups visual separation | `.secondaryAction` for left side items (creates separate visual group from back button), `.primaryAction` for right side items |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 15:45

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**SHIP YES.** Clean, consolidated, user-requested.

The toolbar places all four buttons in a single `.primaryAction` group on the right, per user's explicit request:

1. **Ruthless simplicity**: Four icons total. Search, Add, Filter, Duplicate. Nothing superfluous. Each serves a distinct purpose. Nothing to remove.

2. **One clear primary action**: The "plus" button (New Item) is the creation affordance, positioned prominently in the group. Cmd+N shortcut reinforces primacy.

3. **Strong hierarchy**: All utility actions at consistent visual weight. In a four-button toolbar, this uniformity is correct - no single button should visually dominate.

4. **No clutter**: Icon-only design. No labels. Tooltips and keyboard shortcuts provide discoverability without visual noise in the toolbar itself.

5. **Native feel**: Single `.primaryAction` group on the right is standard macOS toolbar pattern. Consolidated grouping is a legitimate design choice matching many Apple apps.

**Execution quality**:
- SF Symbols: magnifyingglass, plus, square.on.square (consistent weight)
- FilterMenu: Design system component (verified at Dispatch/Design/Shared/Components/FilterMenu.swift)
- Accessibility: All buttons have .accessibilityLabel() and .accessibilityHint()
- Tooltips: All buttons have .help() for macOS hover
- Keyboard shortcuts: Cmd+F (search), Cmd+N (new), Cmd+Shift+N (duplicate)
- Conditional: Duplicate button respects supportsMultipleWindows

This is minimal, discoverable, and respects the user's explicit design intent.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
