## Interface Lock

**Feature**: FAB UX Fixes - Menu Anchoring and Listing Pre-selection
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

### User Complaints (Context)

1. **Menu presentation wrong**: `confirmationDialog` centers on screen. User wants menu anchored to FAB button.
2. **Listing detail behavior wrong**: Should only show "New Task" / "New Activity" (no listing option), and the listing should be PRE-SELECTED automatically.
3. **Listing list screens correct**: Single action "New Listing" already works correctly.

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | Replace `confirmationDialog` with `Menu` attached to FAB |
| `Dispatch/App/Platform/iPadContentView.swift` | Same - replace `confirmationDialog` with `Menu` |
| `Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` | Verify pre-selection logic works (already has init param) |

### Implementation Pattern

Use the established `Menu` pattern from `FloatingFilterButton.swift`:

```swift
// For FAB with multiple options (workspace, listingDetail, realtor contexts)
Menu {
  Button { /* action */ } label: { Label("Option", systemImage: "icon") }
  // ... more options
} label: {
  FloatingActionButton() // The visual FAB
}
.menuIndicator(.hidden)
```

This makes the menu appear anchored to the FAB button on tap.

### Acceptance Criteria (3 max)

1. FAB menu appears attached/anchored to the FAB button, not centered on screen (both iPhone and iPad)
2. On listing detail: FAB shows only "New Task" / "New Activity" options (no "New Listing")
3. On listing detail: Creating task/activity pre-selects current listing (not "None")

### Non-goals (prevents scope creep)

- No changes to workspace FAB behavior (still shows Task/Activity/Listing)
- No changes to single-action contexts (listingList, properties)
- No changes to macOS (already uses Menu pattern for toolbar actions)
- No changes to FABContext enum structure

### Compatibility Plan

- **Backward compatibility**: N/A - UI-only change
- **Default when missing**: N/A
- **Rollback strategy**: Revert to `confirmationDialog` if issues found

---

### Ownership

- **feature-owner**: Replace confirmationDialog with Menu in GlobalFloatingButtons.swift and iPadContentView.swift; verify pre-selection flow
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftUI Menu component how to create menu attached anchored to button label menuIndicator hidden
CONTEXT7_TAKEAWAYS:
- Menu with custom label: `Menu { items } label: { customView }`
- Use `.menuIndicator(.hidden)` to suppress the dropdown indicator
- Menu automatically anchors to its label view
- primaryAction can be used for tap vs hold behavior (not needed here)
- Buttons inside Menu use Label with systemImage for icon+text
CONTEXT7_APPLIED:
- Menu wrapping FAB -> GlobalFloatingButtons.swift:95-151 and iPadContentView.swift:222-278

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| SwiftUI Menu anchored to button label | `Menu { } label: { fabVisual }` with `.menuIndicator(.hidden)` |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 (jobs-critic)

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Native Feel**: The change from `confirmationDialog` to `Menu` is correct. confirmationDialog creates a centered action sheet which breaks spatial continuity. Menu anchors to its label view, creating the expected "options come from the button" interaction pattern.

**Consistency**: Implementation matches the existing FloatingFilterButton pattern (Menu with `.menuIndicator(.hidden)` and custom label view), ensuring visual and behavioral consistency across the app's floating button system.

**Context Awareness**:
- Single-option contexts (listingList, properties) use direct tap - correct
- Multi-option contexts (workspace, listingDetail, realtor) use Menu - correct
- Listing detail correctly limits to Task/Activity only - no redundant "New Listing" option

**Design System Compliance**: Uses DS.Icons.Entity, DS.Colors.accent, DS.Shadows.elevated, DS.Spacing.floatingButtonSizeLarge. fabVisual matches FloatingActionButton component styling.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
