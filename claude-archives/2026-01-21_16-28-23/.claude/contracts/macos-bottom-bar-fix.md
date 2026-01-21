## Interface Lock

**Feature**: macOS Bottom Toolbar Button Fixes
**Created**: 2026-01-18
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

1. All three unused buttons removed from macOS bottom toolbar (plus.square, calendar, arrow.right)
2. ToolbarIconButton shows text label on hover (tooltip-style) using accessibilityLabel
3. FilterMenu has identical hover effect (background highlight + text label) as ToolbarIconButton

### Non-goals (prevents scope creep)

- No changes to iOS/iPadOS toolbar behavior
- No changes to the actual button functionality (actions remain the same)
- No new buttons added
- No changes to detail toolbar (only list toolbar affected)

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only change)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits to restore previous button layout

---

### Files to Modify

| File | Changes |
|------|---------|
| `Dispatch/Foundation/Platform/macOS/BottomToolbar.swift` | Remove 3 placeholder buttons (plus.square, calendar, arrow.right) |
| `Dispatch/Foundation/Platform/macOS/ToolbarIconButton.swift` | Add hover text label display |
| `Dispatch/Design/Shared/Components/FilterMenu.swift` | Add hover effect + text label matching ToolbarIconButton |

### Ownership

- **feature-owner**: Implement all button removal and hover behavior changes
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: macOS help modifier tooltip hover text label button
CONTEXT7_TAKEAWAYS:
- Use `.help(_:)` modifier to add tooltip text that shows on macOS hover
- `.help()` also sets the accessibility hint automatically
- Use `.onHover` modifier to track hover state for custom visual feedback
- The help text displays as a tooltip in macOS and visionOS
- Can combine `.help()` with custom `.onHover` for both tooltip and visual feedback
CONTEXT7_APPLIED:
- `.help()` modifier -> ToolbarIconButton.swift:47, FilterMenu.swift:54
- `.onHover` pattern -> FilterMenu.swift:47-48 (already existed in ToolbarIconButton)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| macOS help modifier tooltip hover text label button | `.help()` modifier for native macOS tooltips, `.onHover` for hover state tracking |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The toolbar changes accomplish exactly what was needed:

1. **Simplicity achieved**: Removed 3 unused placeholder buttons (plus.square, calendar, arrow.right). Only actionable buttons remain: filter, new, search on list views; delete on detail views.

2. **Consistent hover behavior**: FilterMenu now has identical hover background to ToolbarIconButton (RoundedRectangle with Color.primary.opacity(0.08) fill, same animation timing).

3. **Native tooltips**: Uses .help() modifier which is the platform-idiomatic macOS pattern. Displays native tooltip on hover after system delay.

4. **Proper platform isolation**: All macOS-specific code guarded with #if os(macOS).

5. **Design system compliance**: Uses DS.Spacing tokens throughout, DS.Colors.RoleColors for filter tint, accessibility properly implemented.

No changes required.

---

### Implementation Notes

**Context7 Recommended For:**
- SwiftUI `.help()` modifier vs custom tooltip implementation for hover labels
- SwiftUI `onHover` modifier best practices for macOS

**Technical Approach:**
1. ToolbarIconButton: Add optional `hoverLabel` parameter (can default to accessibilityLabel)
2. Show label as tooltip or inline text below/beside icon on hover
3. FilterMenu: Add `@State isHovering` and same hover background as ToolbarIconButton
4. FilterMenu: Show "Filter" label on hover

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
