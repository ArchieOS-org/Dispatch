## Interface Lock

**Feature**: iPad NavigationSplitView Layout Oscillation Fix (Material Modifier Removal)
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Problem Analysis

**Crash Symptom**:
iPad crashes due to infinite layout loop in UICollectionView. Console shows:
```
Collection view is stuck in its update loop. This can happen when self-sizing views do not return consistent sizes
```

**Observed Behavior**:
- 1-point height oscillation (325px <-> 326px) in sidebar UICollectionView
- Stack overflow after ~100 iterations of measurement loop
- Occurs on iPad Pro 13" M5 simulator

**Root Cause**:
The `.containerBackground(.thinMaterial, for: .navigation)` modifier in `SidebarMaterialModifier` causes measurement instability when applied to List content inside NavigationSplitView. The modifier interferes with UICollectionView's self-sizing cell calculations.

**Affected Files**:
- `/Dispatch/Features/Menu/Views/Components/UnifiedSidebar.swift` (lines 92, 98-119)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Note**: This is a code removal fix with detailed prior analysis. All complexity indicators are unchecked because:
- No schema changes
- No new UI (removing problematic code)
- Low risk (removing code, not adding)
- Familiar area (analysis already provided)

### Patchset Plan

Minimal 2-patchset protocol for bug fix:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Validates on iPad + macOS | integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Solution

Remove the `SidebarMaterialModifier` and let NavigationSplitView handle materials natively:

1. **Remove modifier usage** (line 92):
   ```swift
   // REMOVE THIS LINE:
   .modifier(SidebarMaterialModifier())
   ```

2. **Delete SidebarMaterialModifier struct** (lines 98-119):
   ```swift
   // DELETE ENTIRE STRUCT:
   #if os(iOS)
   private struct SidebarMaterialModifier: ViewModifier { ... }
   #endif
   ```

3. **Update comments** (lines 87-91): Remove obsolete comments about material strategy

**Why this works**: NavigationSplitView on iOS 26+ provides native Liquid Glass materials for sidebar columns. The explicit `.containerBackground(.thinMaterial, for: .navigation)` conflicts with the framework's internal layout calculations, causing measurement oscillation.

### Acceptance Criteria (3 max)

1. iPad sidebar renders without crash or "stuck in update loop" console warnings
2. macOS build succeeds (verify no latent NSCollectionView issues)
3. Rapid navigation between sidebar items does not trigger layout warnings

### Non-goals (prevents scope creep)

- No changes to StageCard sizing (separate issue, separate contract)
- No new material effects or visual changes
- No changes to macOS sidebar implementation

### Compatibility Plan

- **Backward compatibility**: iOS 18-25 fallback is removed; native NavigationSplitView handles material
- **Default when missing**: N/A (bug fix)
- **Rollback strategy**: Revert commit if visual regression on sidebar appearance

---

### Ownership

- **feature-owner**: Remove SidebarMaterialModifier from UnifiedSidebar.swift
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A for pure code removal (no framework patterns being implemented)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A (pure code removal) | N/A |

**Rationale**: This is a pure refactor/removal - no new framework or library code is being written. The fix removes problematic code rather than implementing new patterns.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

Bug fix removing problematic modifier - no customer-facing UI changes.

---

### Validation Checklist

After fix is applied:

- [ ] `xcodebuild -project Dispatch.xcodeproj -scheme Dispatch -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build` succeeds
- [ ] `xcodebuild -project Dispatch.xcodeproj -scheme Dispatch -destination 'platform=macOS' build` succeeds
- [ ] No "stuck in update loop" warnings in console when navigating sidebar
- [ ] Rapid navigation test: tap through all sidebar items 10+ times without crash

---

### Related Contracts

- `.claude/contracts/ipad-sidebar-layout-crash.md` - Alternative approach (StageCard sizing fix)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
