## Interface Lock

**Feature**: DIS-90 - Allow editing assignment after pressing Done
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Note**: This is a simple UI bug fix affecting the interaction pattern of an existing component. No new screens, no layout changes, no hierarchy changes - just making an existing element tappable when it currently is not.

### Patchset Plan

Based on checked indicators (simple fix, base protocol):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Root Cause Analysis

The bug is in `Dispatch/SharedUI/Components/OverlappingAvatars.swift`:

**Current behavior (lines 41-58)**:
- When `userIds.isEmpty` (no assignees) -> Shows `ClaimButton` which has `onAssign` callback to open assignment picker
- When `userIds` is NOT empty (has assignees) -> Shows `avatarStack` with **read-only popover only**

The `onAssign` callback exists in the component but is **only passed to ClaimButton**, which only appears when there are NO assignees. Once someone is assigned, the avatars show a popover listing names but have no edit affordance.

**Fix approach**:
Make the `avatarStack` branch trigger `onAssign` when tapped (similar to how the detail view already does this at `WorkItemDetailView.swift:221-223` where tapping opens the assignee picker).

### Files to Modify

1. `Dispatch/SharedUI/Components/OverlappingAvatars.swift` - Add tap gesture to avatarStack to call `onAssign`

### Acceptance Criteria (3 max)

1. Tapping the avatar stack in a WorkItemRow opens the assignment picker (when `onAssign` callback is provided)
2. Existing behavior preserved: tap/hover popover still shows current assignees
3. ClaimButton behavior unchanged for unassigned items

### Non-goals (prevents scope creep)

- No new assignment UI or sheet design
- No changes to the MultiUserPicker component
- No changes to how assignments are persisted
- No changes to WorkItemDetailView (already works correctly)

### Compatibility Plan

- **Backward compatibility**: N/A (no data changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert single file change

---

### Ownership

- **feature-owner**: Fix OverlappingAvatars to allow assignment editing when users already assigned
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A - This fix uses only basic Swift patterns (optional unwrapping with `if let`) and SwiftUI's standard `onTapGesture` modifier. No framework-specific patterns or APIs that require documentation lookup.

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - Basic Swift/SwiftUI | `if let` optional unwrapping, `.onTapGesture` modifier |

**Justification**: This is a minimal bug fix that adds conditional callback invocation using standard Swift optional binding (`if let onAssign { onAssign() }`). The patterns used are fundamental Swift/SwiftUI constructs that have not changed and do not require documentation lookup.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

This is a bug fix restoring expected functionality, not a new UI feature. UI Review is marked NO because:
- No new screens or navigation flows
- No layout or hierarchy changes
- No changes to primary interaction patterns (just enabling an expected interaction that was missing)
- Aligns with existing behavior in WorkItemDetailView

---

**IMPORTANT**:
- `UI Review Required: NO` -> Jobs Critique section is N/A; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
