## Interface Lock

**Feature**: Centralize Claim Handler Logic
**Created**: 2026-01-18
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

### Patchset Plan

Based on checked indicators (none - simple refactor):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: `onClaim: (WorkItem) -> Void` callback in `WorkItemActions`
- Migration required: N

### Current State Analysis

**4 identical claim handler implementations across 3 files:**

| File | Lines | Has Guard Check |
|------|-------|-----------------|
| ListingDetailView.swift | 270-277 (tasks) | YES |
| ListingDetailView.swift | 349-356 (activities) | YES |
| MyWorkspaceView.swift | 262-268 | NO |
| RealtorProfileView.swift | 121-127 | NO |

**Pattern (duplicated):**
```swift
onClaim: {
  // guard syncManager.currentUserID != nil else { return }  // INCONSISTENT
  var newAssignees = item.assigneeUserIds
  if !newAssignees.contains(currentUserId) {
    newAssignees.append(currentUserId)
  }
  actions.onAssigneesChanged(item, newAssignees)
}
```

**Issue:** Guard check is inconsistent - ListingDetailView has it, others do not.

### Proposed Solution

Add `onClaim` callback to `WorkItemActions.swift`:

```swift
/// Claim a work item by adding current user to assignees
@MainActor var onClaim: (WorkItem) -> Void = { _ in }
```

**Wiring in ContentView (where actions is configured):**
```swift
actions.onClaim = { item in
  guard syncManager.currentUserID != nil else { return }
  var newAssignees = item.assigneeUserIds
  if !newAssignees.contains(currentUserId) {
    newAssignees.append(currentUserId)
  }
  actions.onAssigneesChanged(item, newAssignees)
}
```

**Simplified call sites:**
```swift
onClaim: { actions.onClaim(item) }
```

### Acceptance Criteria (3 max)

1. All 4 claim handlers replaced with `actions.onClaim(item)` call
2. Guard check for `currentUserID != nil` standardized (present in centralized handler)
3. All existing tests pass; no behavioral regression

### Non-goals (prevents scope creep)

- No new unit tests for claim logic (existing coverage via integration)
- No changes to WorkItemRow component
- No refactoring of other WorkItemActions callbacks

### Compatibility Plan

- **Backward compatibility**: N/A - internal refactor only
- **Default when missing**: `onClaim` defaults to no-op `{ _ in }` (same as other callbacks)
- **Rollback strategy**: Revert commit; no data changes

---

### Ownership

- **feature-owner**: Implement onClaim in WorkItemActions, wire in ContentView, update 3 view files
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A - Pure refactor with no framework/library usage

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - Pure refactor | N/A |

**N/A**: Valid - this is a pure refactor with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

Not required - UI Review Required: NO (no visual changes, pure logic refactor)

---

### Implementation Notes

**Files to modify:**

1. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu-v1/Dispatch/Features/WorkItems/State/WorkItemActions.swift`
   - Add `@MainActor var onClaim: (WorkItem) -> Void = { _ in }`

2. Wire `onClaim` in ContentView where other callbacks are wired (find existing `actions.onAssigneesChanged` wiring)

3. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu-v1/Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift`
   - Lines 270-277: Replace with `onClaim: { actions.onClaim(.task(task)) }`
   - Lines 349-356: Replace with `onClaim: { actions.onClaim(.activity(activity)) }`

4. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu-v1/Dispatch/Features/Workspace/Views/Screens/MyWorkspaceView.swift`
   - Lines 262-268: Replace with `onClaim: { actions.onClaim(item) }`

5. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu-v1/Dispatch/Features/Realtors/Views/Screens/RealtorProfileView.swift`
   - Lines 121-127: Replace with `onClaim: { actions.onClaim(item) }`

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
