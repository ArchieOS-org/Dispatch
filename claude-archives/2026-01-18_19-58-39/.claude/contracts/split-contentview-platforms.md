## Interface Lock

**Feature**: Split ContentView into Platform-Specific Views
**Created**: 2026-01-17
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO (internal refactoring, no visual changes)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (none - this is a pure refactoring):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles on all platforms | feature-owner |
| 2 | All platforms work identically, tests pass | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. ContentView.swift is reduced to <300 lines and acts as thin platform coordinator
2. All 3 platforms (iPhone, iPad, macOS) work identically to before the refactoring
3. Platform-specific views are cleanly separated: iPhoneContentView.swift, iPadContentView.swift, MacContentView.swift

### Non-goals (prevents scope creep)

- No changes to navigation behavior
- No visual changes or UI improvements
- No new features or functionality
- No refactoring of AppRouter, AppState, or other dependencies

### Compatibility Plan

- **Backward compatibility**: N/A (internal refactoring only)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert if any platform breaks

---

### Ownership

- **feature-owner**: Extract platform navigation code into 3 new files, refactor ContentView to thin coordinator
- **data-integrity**: Not needed

---

### Implementation Details

#### Current Structure Analysis (ContentView.swift - 1069 lines)

**Shared Logic (remains in ContentView):**
- Environment objects: `syncManager`, `appState`, `modelContext` (lines 52-54)
- Query properties: `users`, `allListings`, `allTasksRaw`, `allActivitiesRaw`, etc. (lines 75-81)
- Computed properties: `workspaceTasks`, `workspaceActivities`, `activeProperties`, etc. (lines 154-188)
- State objects: `workItemActions`, `overlayState`, `keyboardObserver` (lines 83, 112-113)
- Navigation bindings: `selectedTabBinding`, `selectedDestinationBinding`, `phonePathBinding` (lines 124-146)
- Helper methods: `pathBinding(for:)`, `selectSearchResult(_:)`, `updateWorkItemActions()`, `updateLensState()` (lines 825-1054)
- `bodyCore` view with offline indicator and debug probe (lines 607-640)

**Platform-Specific (extract to separate files):**

1. **iPhoneContentView.swift** (extract from lines 660-734):
   - `menuNavigation` view
   - Search overlay handling
   - `GlobalFloatingButtons` overlay
   - Sheet handling for iPhone

2. **iPadContentView.swift** (extract from lines 394-590):
   - `ipadTabViewNavigation` view
   - TabView with `.sidebarAdaptable` style
   - `stagePickerButton` and `stagePickerSheet`
   - `tabRootView(for:)` method
   - `badgeCount(for:)` method
   - `iPadFABOverlay` view
   - iPad sidebar helpers (`sidebarCount`, `sidebarOverdueCount`)

3. **MacContentView.swift** (extract from lines 201-389):
   - `sidebarNavigation` view with `ResizableSidebar`
   - `macTabRootView(for:)` method
   - `toolbarContext` computed property
   - `macTabCounts` dictionary
   - `quickFindOverlay` view
   - `sheetContent(for:)` method
   - macOS-specific state: `quickFindText`, `sidebarSelectionBinding`
   - macOS keyboard handling and focus state

#### File Structure After Refactoring

```
Dispatch/App/
  ContentView.swift              # <300 lines - thin coordinator
  Platform/
    iPhoneContentView.swift      # iPhone-specific navigation
    iPadContentView.swift        # iPad-specific navigation
    MacContentView.swift         # macOS-specific navigation
```

#### Shared Types to Consider

Platform views will need access to:
- `@EnvironmentObject var syncManager: SyncManager`
- `@EnvironmentObject var appState: AppState`
- Computed data: `workspaceTasks`, `activeListings`, `stageCounts`, etc.
- Bindings: `selectedDestinationBinding`, `phonePathBinding`, etc.
- Methods: `selectSearchResult(_:)`, `pathBinding(for:)`

**Approach**: Pass these via initializers or use a shared `ContentViewContext` struct to bundle dependencies.

---

### Context7 Queries

Log all Context7 lookups here:

- N/A - Pure refactoring: no new framework/library patterns introduced

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: None (pure code reorganization)

| Query | Pattern Used |
|-------|--------------|
| N/A | This is a pure refactoring that moves existing code into separate files without introducing any new SwiftUI patterns, Supabase usage, or other framework APIs. All patterns were already established in the original ContentView.swift. |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist

N/A - Internal refactoring with no visual changes

#### Verdict Notes

Jobs Critique not required for this contract as UI Review Required is set to NO. This is an internal code organization refactoring that does not change any user-facing UI.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
