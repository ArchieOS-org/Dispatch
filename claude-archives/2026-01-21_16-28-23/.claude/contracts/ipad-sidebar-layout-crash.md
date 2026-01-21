## Interface Lock

**Feature**: iPad Sidebar Infinite UICollectionView Layout Loop Crash Fix
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Problem Analysis

**Crash Symptom**:
iPad simulator freezes with stack overflow when navigating the sidebar. Console shows:
```
Collection view is stuck in its update loop. This can happen when self-sizing views do not return consistent sizes
```

**Root Cause**:
Item (0-0) oscillates between `preferredSize` 325.0 and 326.0 pixels on every layout pass, causing infinite recursive calls to `-[UICollectionView _updateVisibleCellsNow:]`.

**Affected Component**:
`SwiftUI.UpdateCoalescingCollectionView` with data source `SidebarDestination` - this corresponds to the `UnifiedSidebarContent` List on iPad.

**Probable Culprit**: The `StageCardsSection` inside a `List` `Section`:
1. Uses `LazyVGrid` nested inside a `List` row - complex self-sizing
2. `StageCard` uses flexible height: `.frame(minHeight: 88, maxHeight: 120)` with `Spacer(minLength: 0)`
3. Dynamic typography via `@ScaledMetric` for icon size
4. The 1-point oscillation (325 vs 326) suggests floating-point rounding instability

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - iPad crash
- [x] **Unfamiliar area** (adds dispatch-explorer) - Self-sizing cell behavior

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, crash fixed | feature-owner, integrator |
| 3 | iPad validation | xcode-pilot |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Likely Fix Approaches

The self-sizing oscillation typically occurs when:
1. **Flexible height + intrinsic content** - The view's intrinsic size depends on available width, which depends on height
2. **Nested scroll views** - `LazyVGrid` inside `List` (both use UICollectionView)
3. **Rounding errors** - CGFloat calculations that round differently on each pass

**Fix Options (in order of preference)**:

| Option | Approach | Files Modified |
|--------|----------|----------------|
| A | Pin `StageCard` to fixed height (remove flexible frame) | `StageCard.swift` |
| B | Use `.fixedSize()` on `StageCardsSection` to prevent re-measurement | `UnifiedSidebar.swift` or `StageCardsSection.swift` |
| C | Calculate deterministic height using `GeometryReader` once | `StageCard.swift` or `StageCardsGrid.swift` |
| D | Move `StageCardsSection` outside the `List` (above it, not inside a Section) | `UnifiedSidebar.swift` |

**Recommended**: Option A or B first - minimal change, predictable sizing. Option D is more invasive but may be needed if the nested-collection-views architecture is fundamentally unstable.

### Files to Investigate

| File | Reason |
|------|--------|
| `Dispatch/Features/Menu/Views/Components/UnifiedSidebar.swift` | Contains the iPad sidebar List with nested StageCardsSection |
| `Dispatch/Features/Listings/Views/Components/StageCards/StageCard.swift` | Has flexible height frame causing oscillation |
| `Dispatch/Features/Listings/Views/Components/StageCards/StageCardsGrid.swift` | Contains LazyVGrid nested in List |
| `Dispatch/Features/Listings/Views/Components/StageCards/StageCardsSection.swift` | Wrapper that may need `.fixedSize()` |
| `Dispatch/App/Platform/iPadContentView.swift` | iPad container - verify sidebar usage |

### Acceptance Criteria (3 max)

1. **iPad sidebar renders without crash**: Navigate to all sidebar destinations without stack overflow or console warnings about self-sizing
2. **Stage cards grid displays correctly**: All 6 stage cards visible in 2x3 grid with proper spacing
3. **No regression on iPhone/macOS**: Sidebar/menu still renders correctly on other platforms

### Non-goals (prevents scope creep)

- No redesign of stage cards layout (keep current 2x3 grid)
- No changes to stage card tap behavior
- No changes to sidebar selection behavior
- No macOS sidebar changes (macOS uses different code path)

### Compatibility Plan

- **Backward compatibility**: N/A (bug fix)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit if fix causes visual regression

---

### Ownership

- **feature-owner**: Diagnose root cause, implement fix for self-sizing instability
- **data-integrity**: Not needed
- **dispatch-explorer**: Recommended - understand StageCards self-sizing behavior
- **xcode-pilot**: Validate fix on iPad Pro 13-inch (M5) simulator

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

**Required queries before implementation:**

| Topic | Query |
|-------|-------|
| LazyVGrid in List | "LazyVGrid inside List row self-sizing UICollectionView nested" |
| fixedSize modifier | "fixedSize modifier prevent view re-measurement sizing" |
| frame minHeight maxHeight | "frame minHeight maxHeight flexible sizing oscillation" |
| List row sizing | "List row height self-sizing consistent intrinsic content size" |

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| frame minHeight maxHeight flexible height fixed sizing self-sizing cells List | Fixed `.frame(height:)` instead of flexible min/max constraints to prevent layout oscillation |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

This is a bug fix that does not change visible UI appearance - only fixes crash behavior.

---

### Technical Notes

**Understanding the crash mechanism:**

SwiftUI's `List` on iPad uses `UICollectionView` with self-sizing cells. Each cell asks its content for `intrinsicContentSize`. If the returned size differs by even 1 point between layout passes, UIKit interprets this as "content changed" and triggers another layout pass. This creates an infinite loop.

**Why 325 vs 326?**

The `StageCard` uses:
```swift
.frame(minHeight: DS.Spacing.StageCards.cardMinHeight, maxHeight: DS.Spacing.StageCards.cardMaxHeight)
// minHeight: 88, maxHeight: 120
```

Combined with `LazyVGrid` flexible columns and `Spacer(minLength: 0)`, the final height depends on:
1. Available width (changes based on sidebar width)
2. `@ScaledMetric` icon size (can change between passes)
3. Floating-point rounding in layout calculations

The 1-point difference likely comes from different rounding (floor vs ceil) on alternating passes.

**Safe fix pattern:**

Pin the height explicitly rather than using flexible constraints:
```swift
// Before (flexible - causes oscillation):
.frame(minHeight: 88, maxHeight: 120)

// After (fixed - stable):
.frame(height: 88)
```

Or use `.fixedSize()` at the Section level to prevent re-measurement.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
