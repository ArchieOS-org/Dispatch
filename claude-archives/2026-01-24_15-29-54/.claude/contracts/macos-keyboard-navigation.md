## Interface Lock

**Feature**: macOS Keyboard Navigation Handlers
**Created**: 2026-01-17
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO (macOS-only behavioral changes, no customer-facing UI changes, no layout/hierarchy changes)

### Problem Statement
- Limited keyboard navigation - only `ContentView.swift` uses `.focusable()` and `.onKeyPress()` for type-to-search
- No `.onDeleteCommand` or `.onMoveCommand` handlers anywhere in codebase
- No `Settings { }` scene for macOS preferences

### Contract
- New/changed model fields: None
- DTO/API changes: None
- State/actions added:
  - `@FocusState` for list row selection tracking in list views (macOS only)
  - `.onDeleteCommand` handlers for delete confirmation on selected items
  - `.onMoveCommand` handlers for arrow key navigation in lists
  - `Settings { }` scene in DispatchApp for macOS preferences
- UI events emitted: None
- Migration required: N

### Files to Modify
1. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/App/DispatchApp.swift` - Add `Settings { }` scene
2. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/Features/Listings/Views/Screens/ListingListView.swift` - Add focus/keyboard handlers
3. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/Features/Properties/Views/Screens/PropertiesListView.swift` - Add focus/keyboard handlers
4. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/Features/Realtors/Views/Screens/RealtorsListView.swift` - Add focus/keyboard handlers
5. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/Features/WorkItems/Views/Containers/WorkItemListContainer.swift` - Add focus/keyboard handlers
6. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift` - Add delete command
7. `/Users/noahdeskin/conductor/workspaces/dispatch/daegu/Dispatch/Features/WorkItems/Views/Components/WorkItem/WorkItemDetailView.swift` - Add delete command
8. New: `Dispatch/Features/Settings/Views/MacOSSettingsView.swift` - Settings scene content

### Acceptance Criteria (3 max)
1. Arrow keys (up/down) navigate between list items on macOS with visible selection indicator
2. Delete key triggers delete confirmation alert for selected item in lists and detail views
3. macOS Settings scene opens with Cmd+, and provides basic app preferences

### Non-goals (prevents scope creep)
- No iOS/iPadOS keyboard changes (handled by system)
- No custom focus ring styling (use system defaults with `.focusEffectDisabled()` where appropriate)
- No keyboard shortcuts beyond delete and arrow navigation
- No changes to existing type-to-search behavior

### Implementation Notes

#### Context7 Research Required
Before implementing, feature-owner MUST query Context7 for:
- SwiftUI `@FocusState` patterns for list row selection
- `.onMoveCommand(perform:)` macOS patterns
- `.onDeleteCommand(perform:)` macOS patterns
- macOS `Settings { }` scene configuration

#### Pattern to Follow
```swift
// List view example (macOS only)
#if os(macOS)
@FocusState private var focusedItemID: UUID?
#endif

// In body:
List(selection: $focusedItemID) {
  ForEach(items) { item in
    // row content
  }
}
#if os(macOS)
.onMoveCommand { direction in
  // Handle arrow key navigation
}
.onDeleteCommand {
  // Show delete confirmation for focusedItemID
}
#endif
```

### Compatibility Plan
- **Backward compatibility**: All changes are additive, macOS-only
- **Default when missing**: N/A
- **Rollback strategy**: Remove `#if os(macOS)` blocks

### Ownership
- **feature-owner**: Full vertical slice - all keyboard navigation surfaces
- **data-integrity**: Not needed (no schema changes)

---

### Patchset Protocol

- [x] PATCHSET 1: Add `@FocusState` and `.focusable()` to list views + Settings scene stub
- [x] PATCHSET 2: Add `.onMoveCommand` handlers for arrow navigation
- [x] PATCHSET 3: Add `.onDeleteCommand` handlers to lists and detail views
- [x] PATCHSET 4: Cleanup, Tab key verification, build macOS + run tests

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Verdict Notes
UI Review not required - macOS-only behavioral changes with no customer-facing UI impact.

---

**IMPORTANT**:
- `UI Review Required: NO` - Jobs Critique section is not required; integrator skips this check
- integrator verifies macOS build and keyboard navigation functionality
