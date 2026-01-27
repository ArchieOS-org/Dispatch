## Interface Lock

**Feature**: Audit History Display Fix - Vague Summaries, Duplicates, Assignee Attribution
**Created**: 2026-01-24
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

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

### Problem Summary

The audit history UI shows vague, duplicated, and incomplete entries:

1. **Vague summaries**: All updates say "made changes" without specifics
2. **Multiple "Created" entries**: Each assignee INSERT shows as separate entry
3. **Duplicate entries**: Same timestamp entries not collapsed
4. **Missing assignee details**: No info on who assigned whom, claims, or unassigns

### Root Causes

| Issue | Location | Cause |
|-------|----------|-------|
| Vague summaries | `AuditSummaryBuilder.swift:102-103` | Falls back to "made changes" when oldRow/newRow comparison fails |
| Multiple "Created" | `AuditSyncHandler.swift:312-313` | `fetchCombinedHistory()` merges task + assignee logs without deduplication |
| Missing assignee detail | `AuditSummaryBuilder.swift:50-77` | `buildAssignmentSummary()` uses generic text, no actor attribution |
| Field detection failures | `AuditSummaryBuilder.swift:110` | AnyCodable stringification may fail on complex types |

### Contract

- New/changed model fields: None
- DTO/API changes: None (display logic only)
- State/actions added: None
- Migration required: N

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/Foundation/Audit/AuditSummaryBuilder.swift` | Enhance summaries: specific field changes, proper assignee attribution with actor names |
| `Dispatch/Foundation/Audit/AuditEntryDTO.swift` | Add helper methods for context-aware assignee labels if needed |
| `Dispatch/Features/History/HistorySection.swift` | Add deduplication logic for combined history (collapse same-timestamp entries) |

### Acceptance Criteria (3 max)

1. **Specific change summaries**: Updates show field names and values (e.g., "changed status from Open to In Progress") instead of "made changes"
2. **Proper assignee attribution**: Shows "Alice assigned Bob" vs "Bob claimed this task" vs "Alice unassigned Bob" with actor names
3. **Single "Created" entry**: Task creation + initial assignees collapsed into one logical entry with details

### Non-goals (prevents scope creep)

- No changes to the audit RPC functions or database schema
- No new history detail views or navigation flows
- No changes to restore functionality
- No changes to audit trigger behavior

### Compatibility Plan

- **Backward compatibility**: N/A - display logic only, no data changes
- **Default when missing**: Fallback to "made changes" if field comparison still fails (graceful degradation)
- **Rollback strategy**: Revert to previous summary builder logic

---

### Ownership

- **feature-owner**: End-to-end implementation of summary improvements and deduplication
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Notes

**Deduplication Strategy**:
- Group entries by (changedAt rounded to nearest second, changedBy)
- Collapse INSERT entries at creation time into single "Created" with details
- Preserve individual UPDATE entries (they represent distinct changes)

**Assignee Attribution**:
- `assigned_by` field in row data tells who performed the action
- Compare `assigned_by` to `user_id` to determine claim vs assignment
- Actor name comes from `userLookup` callback at render time

**AnyCodable Comparison Fix**:
- Add explicit type handling for common types (String, Int, Double, Bool, UUID)
- Fallback to string comparison only after explicit type check fails

---

### Context7 Attestation [MANDATORY]

> **Enforcement**: Integrator BLOCKS DONE if required reports are missing or CONTEXT7 CONSULTED: NO

#### Required Libraries (filled by planner or feature-owner)

| Library | Context7 ID | Why Needed |
|---------|-------------|------------|
| SwiftUI | /websites/developer_apple_swiftui | View binding patterns for deduplication display |

**N/A is only valid** for pure refactors with no framework/library usage.

---

#### Agent Reports

Each agent fills their section below. **Integrator verifies these are complete before DONE.**

##### feature-owner Report (MUST FILL)

**CONTEXT7 CONSULTED**: YES

| Library | Query | Result |
|---------|-------|--------|
| Swift | Dictionary grouping values by key and reduce collection to merge duplicates | Use Dictionary(grouping:by:) for grouping, standard collection operations for deduplication |
| Swift | Dictionary init grouping values by key sequence collection | Standard Swift Dictionary grouping patterns confirmed |

**CONTEXT7_QUERY**: Dictionary grouping values by key and reduce collection to merge duplicates
**CONTEXT7_TAKEAWAYS**:
- Use Dictionary(grouping:by:) for grouping array elements by key
- Standard Set operations for tracking seen keys during deduplication
- Collection iteration with continue/break for filtering
**CONTEXT7_APPLIED**:
- Set-based deduplication -> HistorySection.swift:deduplicateEntries()

_N/A only valid for pure refactors with zero framework code._

##### ui-polish Report (FILL IF CODE CHANGES)

**CODE CHANGES MADE**: PENDING

| Library | Query | Result |
|---------|-------|--------|
| | | |

_Leave empty if no code changes (review only)._

##### swift-debugger Report (FILL IF INVOKED)

**DEBUGGING PERFORMED**: NO

| Library | Query | Result |
|---------|-------|--------|
| | | |

_Leave empty if swift-debugger not invoked._

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-24 16:45

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

Summary text is specific and actionable ("changed status to In Progress" vs vague "made changes"). Assignee attribution follows natural language patterns: "Alice assigned Bob" / "Bob claimed this" / "Bob removed themselves". Deduplication correctly collapses same-timestamp INSERT entries to eliminate duplicate "Created" rows. Typography hierarchy is correct with DS.Typography tokens. Accessibility properly implemented with combined labels for VoiceOver. All loading/empty/error states handled cleanly. Uses design system components throughout.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE

**Context7 Attestation [MANDATORY]**:
- Integrator MUST verify each agent's Context7 report is filled:
  - **feature-owner**: MUST have report with `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors)
  - **ui-polish**: MUST have report if `CODE CHANGES MADE: YES`
  - **swift-debugger**: MUST have report if `DEBUGGING PERFORMED: YES`
- If any required report is missing or shows `CONTEXT7 CONSULTED: NO` -> integrator MUST reject DONE
- `N/A` is only valid for pure refactors with zero framework/library code
