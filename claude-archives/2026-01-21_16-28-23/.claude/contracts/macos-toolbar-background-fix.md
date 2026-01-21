## Interface Lock

**Feature**: macOS Toolbar/Sidebar Background Fix
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

### Problems to Fix

1. **Opaque background blocking toolbar area** (`StandardScreen.swift:152-153`)
   - `DS.Colors.Background.primary.ignoresSafeArea()` extends opaque color under titlebar
   - Should NOT extend under toolbar on macOS - blocks transparent titlebar integration
   - **Fix**: On macOS, exclude top edge from `.ignoresSafeArea()` or use platform-specific handling

2. **Custom macOS title header creating visual block** (`StandardScreen.swift:177-187`)
   - "Things 3 style" custom `Text(title)` header on macOS with padding
   - Creates unwanted visual content at top of detail view
   - **Fix**: Remove this custom header; use native `.navigationTitle()` instead (already applied at line 103)

### Do NOT Change

- `.scrollEdgeEffectStyle(.soft, for: .top)` - leave as is (last resort modifier)

### Acceptance Criteria (3 max)

1. macOS toolbar/titlebar area shows transparent glass effect (not blocked by opaque background)
2. Detail view uses native navigation title, no custom "Things 3 style" text header
3. iOS behavior remains unchanged (opaque background still extends under safe area)

### Non-goals (prevents scope creep)

- No changes to iOS layout behavior
- No changes to sidebar structure
- No changes to scroll behavior or edge effects
- No new navigation patterns

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only change)
- **Default when missing**: N/A
- **Rollback strategy**: Revert the two specific changes if visual regression occurs

---

### Files to Modify

- `/Users/noahdeskin/conductor/workspaces/dispatch/san-jose-v1/Dispatch/App/Shell/StandardScreen.swift`
  - Line 152-153: Platform-conditional `.ignoresSafeArea()` for background
  - Line 177-187: Remove macOS custom header block
  - Line 206: Remove `.navigationTitle("")` override since we're using native title

---

### Ownership

- **feature-owner**: Fix background safe area handling and remove custom macOS header
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: ignoresSafeArea edges parameter exclude top edge macOS
CONTEXT7_TAKEAWAYS:
- `ignoresSafeArea(_:edges:)` accepts `Edge.Set` parameter to specify which edges to ignore
- Can use `[.horizontal, .bottom]` to exclude top edge
- Default is `.all` which extends into all safe area edges
- This is the modern API (replaces deprecated `edgesIgnoringSafeArea`)
CONTEXT7_APPLIED:
- Exclude top edge on macOS -> StandardScreen.swift:154-156

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| ignoresSafeArea edges parameter exclude top edge macOS | `ignoresSafeArea(edges: [.horizontal, .bottom])` to exclude top edge on macOS |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

This change exemplifies the Apple philosophy: less is more.

**What was removed:**
1. Custom "Things 3 style" macOS title header - redundant with native `.navigationTitle()`
2. Full-bleed background on macOS that blocked toolbar vibrancy

**What this achieves:**
- Native macOS toolbar/titlebar integration - transparent glass effect works as designed
- Reduced code complexity - platform-specific UI divergence removed
- Consistent with macOS HIG - respects window chrome and toolbar vibrancy expectations

**Technical execution:**
- Correct use of `.ignoresSafeArea(edges: [.horizontal, .bottom])` on macOS to exclude top
- iOS behavior preserved exactly (full `.ignoresSafeArea()` for edge-to-edge)
- Clean `#if os(macOS)` platform conditional - no awkward workarounds

**Design bar passes:** The change removes custom UI in favor of native platform behavior. This is exactly the right direction. When Apple provides a standard control (navigation title, toolbar vibrancy), use it instead of fighting it with custom implementations.

Would Apple ship this? Yes. This is how macOS apps should integrate with the system toolbar.

---

### Implementation Notes

**Context7 Recommendation**: feature-owner should query Context7 for:
- SwiftUI `.ignoresSafeArea()` edge-specific parameters on macOS
- SwiftUI `.navigationTitle()` behavior on macOS vs iOS
- macOS toolbar transparency and window chrome integration patterns

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
