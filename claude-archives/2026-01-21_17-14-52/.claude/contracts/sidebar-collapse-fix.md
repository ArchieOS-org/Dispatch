## Interface Lock

**Feature**: macOS Sidebar Collapse Bug Fix
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO (bug fix - restoring expected behavior, no new UI)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer) - COMPLETED in contract creation

### Patchset Plan

Based on checked indicators (simple bug fix):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (modifying existing clamp logic)
- Migration required: N

### Problem Statement

1. **Console errors**: "Invalid view geometry: width is negative" - occurs repeatedly when collapsing sidebar
2. **Visual bug**: Sidebar "smooshes" (compresses below minimum width) during drag before collapsing
3. **Expected behavior**: Sidebar should lock to minimum width (200pt) during drag, then snap collapse when cursor moves past threshold

### Root Cause Analysis

Location: `/Users/noahdeskin/conductor/workspaces/dispatch/sofia/Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift`

**Current behavior** (lines 32-37):
```swift
private var displayWidth: CGFloat {
  if windowState.isDragging {
    return windowState.clampedWidthDuringDrag(dragStartWidth + dragDelta)
  }
  return windowState.sidebarVisible ? windowState.sidebarWidth : 0
}
```

**Problem**: `clampedWidthDuringDrag` (in `WindowUIState.swift` line 66-68) clamps to `0...max`:
```swift
func clampedWidthDuringDrag(_ newWidth: CGFloat) -> CGFloat {
  min(DS.Spacing.sidebarMaxWidth, max(0, newWidth))
}
```

This allows the sidebar to shrink below its minimum width (200pt) during drag, causing:
- Visual "smooshing" as content compresses
- Potential negative width values if drag delta exceeds start width rapidly

### Acceptance Criteria (3 max)

1. No "Invalid view geometry: width is negative" console errors during sidebar collapse
2. Sidebar visually locks at minimum width (200pt) during drag - no smooshing
3. Sidebar collapses to 0 only after dragging past threshold (minWidth - 30pt)

### Non-goals (prevents scope creep)

- No changes to collapse animation timing
- No changes to sidebar expand behavior
- No changes to keyboard shortcut (Cmd+/) toggle behavior
- No changes to NativeSplitView.swift (separate implementation path)

### Compatibility Plan

- **Backward compatibility**: N/A - internal view behavior
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit if issues arise

---

### Technical Approach

**Option A (Recommended)**: Two-phase drag clamping
- During drag: clamp to `minWidth...maxWidth` (prevents smooshing)
- Show collapse intent visually (e.g., opacity reduction when past threshold)
- On drag end: if past threshold, animate collapse to 0

**Option B**: Keep current approach but ensure no negative values
- Add explicit `max(0, ...)` guard before setting frame width
- Less elegant but minimal change

### Files to Modify

1. `/Users/noahdeskin/conductor/workspaces/dispatch/sofia/Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift`
   - Update `displayWidth` computed property
   - Potentially add collapse intent visual feedback

2. `/Users/noahdeskin/conductor/workspaces/dispatch/sofia/Dispatch/Foundation/Platform/macOS/WindowUIState.swift`
   - Update `clampedWidthDuringDrag` to respect minimum during active drag
   - Or add new method for display-width calculation

---

### Ownership

- **feature-owner**: Fix drag clamping logic to prevent negative widths and smooshing
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7: N/A (pure logic fix - changing numeric clamp bound from 0 to minWidth, no framework patterns involved)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: None - pure arithmetic/logic fix

| Query | Pattern Used |
|-------|--------------|
| N/A | Changed `max(0, newWidth)` to `max(DS.Spacing.sidebarMinWidth, newWidth)` |

**Justification**: This fix modifies a single numeric bound in a clamping function. No SwiftUI patterns, Supabase APIs, or framework-specific behavior is involved. The change is a straightforward substitution of the lower bound constant.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

This is a bug fix with `UI Review Required: NO`. Jobs Critique is not required.

---

### Enforcement Summary

- [x] Contract created and locked
- [x] PATCHSET 1: Compiles on macOS (verified)
- [x] PATCHSET 2: No console errors, no smooshing, passes acceptance criteria
- [x] Context7 Attestation filled (N/A - pure logic fix)
- [ ] Integrator verifies build passes

**IMPORTANT**:
- `UI Review Required: NO` - Jobs Critique section skipped
- Context7 Attestation: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` if pure logic fix) before reporting DONE
