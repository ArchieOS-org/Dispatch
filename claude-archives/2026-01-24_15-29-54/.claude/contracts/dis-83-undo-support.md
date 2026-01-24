## Interface Lock

**Feature**: DIS-83 - Shake to Undo and Command+Z Support
**Created**: 2026-01-21
**Status**: locked
**Lock Version**: v2
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

**Analysis:**
- No schema changes: UndoManager is framework-level, no data model changes
- No complex UI: This is system-level undo infrastructure, not new UI screens
- No high-risk flow: Uses native SwiftUI/UIKit undo patterns
- Unfamiliar area: UndoManager integration patterns need exploration via Context7

### Patchset Plan

Based on checked indicators (unfamiliar area only - base 2 patchsets):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added:
  - UndoManager injection via SwiftUI Environment
  - Shake gesture responder chain enablement (iOS/iPadOS)
  - Command+Z already handled by system when UndoManager is wired
- Migration required: N

### Technical Approach

**Key Discovery: SwiftUI UndoManager Integration**

SwiftUI provides `@Environment(\.undoManager)` for accessing the window's UndoManager. The implementation requires:

1. **UndoManager Registration**: Register undo actions when mutations occur via `undoManager?.registerUndo(withTarget:handler:)`

2. **Shake-to-Undo (iOS/iPadOS)**: Already enabled by default when UndoManager has registered actions. No additional code needed - UIKit responder chain handles shake gesture automatically.

3. **Command+Z (macOS)**: System automatically routes Edit > Undo menu item (Cmd+Z) to the focused window's UndoManager. No additional code needed in `DispatchCommands.swift`.

**Integration Points (identified from codebase):**

| Location | Purpose |
|----------|---------|
| `ContentView.swift` | Inject UndoManager to WorkItemActions |
| `WorkItemActions.swift` | Register undo actions for mutations |
| `Note.swift` | Already has `undoDelete()` method |
| `DispatchApp.swift` | No changes needed - system handles Cmd+Z |

**Undoable Actions (scope):**
- Note soft-delete (already has `undoDelete()` method)
- Task/Activity completion toggle
- Task/Activity assignee changes
- Listing stage changes (via `onListingStageChanged` callback)
- Note creation (via `onAddNote` and `onAddNoteToListing` callbacks - uses `softDelete` for undo)

### Acceptance Criteria (3 max)

1. **iOS/iPadOS**: Shake device after deleting a note shows "Undo Delete" alert; tapping Undo restores the note; shake again shows "Redo Delete" alert
2. **macOS**: Command+Z undoes actions, Command+Shift+Z redoes them (Edit menu shows Undo/Redo with action names)
3. **Cross-platform**: Undo/redo works consistently for note deletion, note creation, task completion toggle, assignee changes, and listing stage changes

### Non-goals (prevents scope creep)

- No custom undo UI (uses system-provided shake alert on iOS)
- No multi-level undo history display
- No undo for navigation actions (only data mutations)
- No undo for sync operations or server-side changes

### Compatibility Plan

- **Backward compatibility**: N/A - no DTO changes
- **Default when missing**: N/A - no new fields
- **Rollback strategy**: Remove UndoManager registration calls; system reverts to no-op undo

---

### Ownership

- **feature-owner**: Integrate UndoManager with WorkItemActions; register undo handlers for note delete, completion toggle, and assignee changes
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: UndoManager environment registerUndo withTarget handler shake to undo
CONTEXT7_TAKEAWAYS:
- Access UndoManager via `@Environment(\.undoManager)` in SwiftUI views
- UndoManager is optional (nil when undo not supported)
- Property is `@MainActor` isolated
- Use `registerUndo(withTarget:handler:)` to register undo actions
- Shake-to-undo and Command+Z work automatically when UndoManager has registered actions
CONTEXT7_APPLIED:
- @Environment(\.undoManager) -> ContentView.swift:27
- registerUndo(withTarget:handler:) -> ContentView.swift:255 (task complete)
- registerUndo(withTarget:handler:) -> ContentView.swift:270 (activity complete)
- registerUndo(withTarget:handler:) -> ContentView.swift:305 (task assignees)
- registerUndo(withTarget:handler:) -> ContentView.swift:338 (activity assignees)
- registerUndo(withTarget:handler:) -> ContentView.swift:393 (note delete)
- registerUndo(withTarget:handler:) -> ContentView.swift:378 (note add to work item)
- registerUndo(withTarget:handler:) -> ContentView.swift:418 (listing stage change)
- registerUndo(withTarget:handler:) -> ContentView.swift:434 (note add to listing)

CONTEXT7_QUERY: UndoManager redo registerUndo how to enable redo support by registering undo inside undo handler
CONTEXT7_TAKEAWAYS:
- Access UndoManager via `@Environment(\.undoManager)` in SwiftUI views
- UndoManager is optional (nil when undo not supported)
- By default, macOS provides Undo and Redo commands via CommandGroupPlacement.undoRedo
- System handles Command+Z for undo and Command+Shift+Z for redo automatically
- To enable redo: inside each undo handler, after restoring state, call registerUndo again with the forward action
CONTEXT7_APPLIED:
- Nested registerUndo for redo -> ContentView.swift:makeOnComplete(), makeOnAssigneesChanged(), makeOnAddNote(), makeOnDeleteNote(), makeOnListingStageChanged(), makeOnAddNoteToListing()

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (developer.apple.com)

| Query | Pattern Used |
|-------|--------------|
| UndoManager environment registerUndo withTarget handler | @Environment(\.undoManager), registerUndo(withTarget:handler:), setActionName() |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

#### Checklist

N/A - UI Review Required: NO (system-level infrastructure, no customer-facing UI changes)

#### Verdict Notes

N/A - This feature uses native system UI (iOS shake alert, macOS Edit menu). No custom UI components introduced.

---

### Implementation Notes

**Context7 Recommended For:**
- SwiftUI `@Environment(\.undoManager)` best practices
- UndoManager `registerUndo(withTarget:handler:)` closure capture patterns
- MainActor isolation with UndoManager (avoid runtime warnings)

**Key Files to Modify:**
1. `/Users/noahdeskin/conductor/workspaces/dispatch/hamburg/Dispatch/App/ContentView.swift` - Access undoManager, pass to WorkItemActions
2. `/Users/noahdeskin/conductor/workspaces/dispatch/hamburg/Dispatch/Features/WorkItems/State/WorkItemActions.swift` - Add undoManager property, register undo actions in callbacks

**Existing Pattern to Leverage:**
- `Note.undoDelete()` method already exists in `/Users/noahdeskin/conductor/workspaces/dispatch/hamburg/Dispatch/Features/WorkItems/Models/Note.swift:96`

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
