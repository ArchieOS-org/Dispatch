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
  // Left side: Filter + Add (always present)
  // Back button displaces these to its right when visible (handled by .navigation placement)
  ToolbarItemGroup(placement: .navigation) {
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

CONTEXT7_QUERY: ToolbarItemGroup placement options macOS navigation primaryAction toolbar positioning
CONTEXT7_TAKEAWAYS:
- `.navigation` placement positions items on leading edge of toolbar in macOS (ahead of inline title)
- `.primaryAction` placement is for primary, frequently used actions
- On macOS/Mac Catalyst, navigation items appear on leading edge of toolbar
- Navigation items appear after system navigation items (like back button)
CONTEXT7_APPLIED:
- `.navigation` for left side (Filter + Add) -> MacContentView.swift:52-59
- `.primaryAction` for right side (Search + Duplicate) -> MacContentView.swift:61-72

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| ToolbarItemGroup placement options macOS navigation primaryAction | `.navigation` for left side items (positions after back button on leading edge), `.primaryAction` for right side items |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**SHIP YES.** This is how Apple does it.

The toolbar reorganization follows native macOS conventions precisely:

1. **Ruthless simplicity**: Four icons total. Filter, Add, Search, Duplicate. Nothing superfluous. Each serves a distinct purpose.

2. **One clear primary action**: The "plus" button for creation is now prominently placed on the left, immediately accessible after any navigation. This is the primary affordance users need when viewing content.

3. **Strong hierarchy**: Left side = context modification (filter what you see, create new items). Right side = utility actions (search, window management). This semantic grouping follows user mental models.

4. **No clutter**: Clean icon-only design. No labels cluttering the toolbar. Tooltips and keyboard shortcuts provide discoverability without visual noise.

5. **Native feel**: The `.navigation` and `.primaryAction` placements are exactly how Apple's own apps (Finder, Mail, Notes) organize toolbars. Filter/Add on left naturally flows after the back button when drilling into navigation. Search on right is the universal macOS pattern.

**Execution quality**:
- SF Symbols used consistently (plus, magnifyingglass, square.on.square)
- FilterMenu is a design system component with proper accessibility
- All buttons have `.help()` tooltips for macOS hover
- Keyboard shortcuts present (Cmd+N, Cmd+F, Cmd+Shift+N)
- Full VoiceOver support with labels and hints
- Conditional rendering of Duplicate button respects window capability

This is a tight, focused change that makes the toolbar feel inevitable.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
