## Interface Lock

**Feature**: macOS Keyboard Shortcuts Fix
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO (menu items exist, this is behavior/wiring fix, not visual change)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Problem Analysis

#### Issue 1: Cmd+N Conflict (FALSE POSITIVE)

**Finding**: No actual conflict exists.
- `Cmd+N` is mapped to "New Item" in `DispatchCommands.swift:34`
- `Cmd+Shift+N` is mapped to "New Window" in `AppShellView.swift:65`
- These are different shortcuts (with/without Shift modifier)

**Action**: No fix needed. User may have observed macOS's default "New Window" menu item conflicting with custom "New Item" - need to verify if SwiftUI CommandGroup is replacing or adding to default items.

#### Issue 2: Filter Shortcuts (Cmd+1/2/3) Do Nothing

**Root Cause**: Commands are dispatched but handlers are stubbed with `break`:

```swift
// AppState.swift lines 206-217
case .filterMine:
  // TODO: Implement AssignmentFilter in LensState
  break

case .filterOthers:
  break

case .filterUnclaimed:
  break
```

**Problem**: The menu items (My Tasks, Others' Tasks, Unclaimed) imply ASSIGNMENT-based filtering, but `LensState.audience` uses ROLE-based filtering (`AudienceLens`: All/Admin/Marketing).

**Options**:
1. **Repurpose shortcuts** - Map Cmd+1/2/3 to existing `AudienceLens` values (All/Admin/Marketing)
2. **Add AssignmentFilter** - Create a new filter dimension for My/Others/Unclaimed
3. **Remove misleading items** - Delete the menu items until assignment filter is implemented

**Recommended**: Option 1 (Repurpose) - Map shortcuts to existing functionality:
- Cmd+1: All (reset filter)
- Cmd+2: Admin lens
- Cmd+3: Marketing lens

OR rename menu items to match existing functionality:
- Cmd+1: "All Items"
- Cmd+2: "Admin Only"
- Cmd+3: "Marketing Only"

#### Issue 3: Menu Item Visibility (Already Working)

User confirmed shortcuts appear in macOS menu bar. No action needed.

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (reusing existing `LensState.audience`)
- Migration required: N

### Acceptance Criteria (3 max)

1. Cmd+1 navigates to "My Workspace" tab (using `userSelectedDestination(.tab(.workspace))`)
2. Cmd+2 and Cmd+3 menu items are completely removed
3. Menu item label for Cmd+1 is "My Workspace" (not "My Tasks")

### Non-goals (prevents scope creep)

- No new AssignmentFilter dimension (future work if needed)
- No changes to filter UI components
- No new keyboard shortcuts beyond fixing existing ones
- No changes to filterOthers/filterUnclaimed notification handlers in other views (they become dead code but harmless)

### Compatibility Plan

- **Backward compatibility**: N/A - behavior change only
- **Default when missing**: N/A
- **Rollback strategy**: Revert to `break` statements

---

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/App/State/AppCommand.swift` | Remove `filterOthers` and `filterUnclaimed` cases |
| `Dispatch/App/State/AppState.swift` | Change `filterMine` to navigate to workspace, remove `filterOthers`/`filterUnclaimed` handlers |
| `Dispatch/App/State/DispatchCommands.swift` | Remove Cmd+2/3 buttons, rename Cmd+1 to "My Workspace" |
| `Dispatch/Foundation/Platform/macOS/SidebarState.swift` | Remove `filterOthers` and `filterUnclaimed` notification names |
| `Dispatch/Features/WorkItems/Views/Containers/WorkItemListContainer.swift` | Remove onReceive handlers for filterOthers/filterUnclaimed |
| `Dispatch/App/Platform/MacContentView.swift` | Update NavigationPopover onNavigate to not use filterUnclaimed/filterMine |

### Ownership

- **feature-owner**: Implement filter command handlers, update menu labels
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftUI Commands CommandGroup keyboard shortcut macOS menu bar
CONTEXT7_TAKEAWAYS:
- Use `CommandGroup(after: .newItem)` to add menu items after the standard "New" menu group
- Use `.keyboardShortcut("key", modifiers: .command)` for keyboard shortcuts
- Remove menu items by simply not including them in the Commands body
CONTEXT7_APPLIED:
- CommandGroup pattern -> DispatchCommands.swift (removing Cmd+2/3 buttons, keeping Cmd+1)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| SwiftUI Commands CommandGroup keyboard shortcut macOS menu bar | CommandGroup with .keyboardShortcut modifier, removing items by exclusion |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

### Enforcement Summary

- UI Review Required: **NO** (menu wiring fix, no visual changes)
- Jobs Critique: **NOT REQUIRED**
- Context7 Attestation: Required at PATCHSET 1
- Integrator verifies: builds pass, filter shortcuts functional

---

### User Decision (2026-01-18)

**Selected approach**: Custom - Navigate to Workspace
- Cmd+1: Navigate to "My Workspace" (actual sidebar navigation, not filtering)
- Cmd+2: Remove entirely
- Cmd+3: Remove entirely

This is a simplification that removes the non-functional filter shortcuts and repurposes Cmd+1 as workspace navigation.
