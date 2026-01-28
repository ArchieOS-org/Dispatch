## Interface Lock

**Feature**: DIS-87 Add Notes/Descriptions to Task/Activity Creation
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES (customer-facing form UI changes)

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

### Analysis Summary

**Schema Status**: NO CHANGES NEEDED
- `tasks.description` already exists (nullable text, default '')
- `activities.description` already exists (nullable text, default '')
- `TaskDTO` and `ActivityDTO` already handle `description` field
- `TaskItem.taskDescription` and `Activity.activityDescription` model properties exist

**Current State**:
- QuickEntrySheet.swift is the unified creation form for Tasks/Activities (via FAB menu)
- Description field exists in schema/models but is NOT exposed in creation UI
- Notes are a separate entity (notes table) added post-creation via NotesSection

**Clarification**: This feature adds the **description** field to creation forms. Notes (as separate entities) are already supported post-creation and are out of scope.

### Contract

- New/changed model fields: None (already exist)
- DTO/API changes: None (already exist)
- State/actions added: @State for description text in QuickEntrySheet
- Migration required: N

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` | Add description TextField, pass to TaskItem/Activity init |

### Acceptance Criteria (3 max)

1. QuickEntrySheet displays an optional description/notes text field below the title field
2. Description is saved when creating Task or Activity (passed to model init)
3. Description field works on both iOS and macOS form layouts

### Non-goals (prevents scope creep)

- No changes to the detail view (description already shown there)
- No changes to the schema or DTOs (already support description)
- No changes to sync handlers (already sync description)
- No inline note creation (notes are separate entities added post-creation)

### Compatibility Plan

- **Backward compatibility**: N/A - no schema/DTO changes
- **Default when missing**: Empty string (existing behavior)
- **Rollback strategy**: Revert QuickEntrySheet.swift changes

---

### Ownership

- **feature-owner**: Add description field to QuickEntrySheet.swift for iOS and macOS form layouts
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: TextField and TextEditor in Form for multiline text input iOS macOS platform differences
CONTEXT7_TAKEAWAYS:
- TextEditor is for multiline, scrollable text - requires @State binding
- TextField is for single-line input with prompt support
- Form uses label/prompt differently by platform (iOS uses prompt as placeholder, macOS shows both)
- Standard view modifiers apply globally to TextEditor content
CONTEXT7_APPLIED:
- Using TextField for description (single-line is sufficient for quick entry) -> QuickEntrySheet.swift:153, 266

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| TextField and TextEditor in Form for multiline text input iOS macOS platform differences | TextField with prompt for optional description field |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline → primary → secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The description field implementation is exemplary for a "quick entry" context:

1. **Single-line TextField is the right choice** - TextEditor would be overkill for quick entry. Users who need extensive notes can add them in the detail view post-creation.

2. **Positioning is correct** - Description appears after Title (secondary to the primary input), before Listing picker. This maintains logical form hierarchy.

3. **Placeholder communicates optionality** - "Add details (optional)" is clear and concise. No required field indicator needed.

4. **Platform parity achieved** - Both iOS Form and macOS LabeledContent implementations follow platform conventions with identical field ordering.

5. **No visual clutter added** - The field blends naturally with existing form rows. No new spacing, styling, or chrome introduced.

The implementation answers "Would Apple ship this?" with a clear yes. It adds functionality without adding complexity.

---

### Implementation Notes

**Context7 Recommended For**:
- SwiftUI Form/TextField patterns for multiline text input
- Platform-specific form styling (iOS vs macOS)

**UI Considerations**:
- Description field should be optional (placeholder text, not required)
- Consider using TextEditor for multiline support, or single-line TextField
- Maintain form hierarchy: Type > Title > Description > Listing > Due Date > Assignees
- Touch target and accessibility requirements per DESIGN_SYSTEM.md

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
