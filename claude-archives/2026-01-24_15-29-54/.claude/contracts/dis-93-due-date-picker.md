## Interface Lock

**Feature**: DIS-93 - Redesign Due Date Picker (Apple HIG Compliance)
**Created**: 2026-01-21
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (existing `@State hasDueDate` and `@State dueDate` are sufficient)
- Migration required: N

### Problem Statement

The current due date picker in `QuickEntrySheet.swift` has a UX issue where the toggle switch moves position when activated. Per Apple HIG, toggle switches should never change position when toggled.

**Current Implementation (lines 240-250 in QuickEntrySheet.swift):**
```swift
private var dueDateRow: some View {
  HStack {
    Text("Due Date")
    Spacer()
    Toggle("", isOn: $hasDueDate)
      .labelsHidden()
    if hasDueDate {
      DatePicker("", selection: $dueDate, displayedComponents: [.date])
        .labelsHidden()
    }
  }
}
```

The DatePicker appearing inline within the HStack causes the toggle to shift left.

### Acceptance Criteria (3 max)

1. Toggle switch remains stationary when toggled ON/OFF
2. When toggled ON, an inline calendar picker appears BELOW the toggle row
3. Works correctly on iOS, iPadOS, and macOS (all three platforms)

### Non-goals (prevents scope creep)

- No changes to the data model or due date storage
- No changes to ActivityType or other form fields
- No new animations beyond standard SwiftUI transitions
- No time picker component (date only, matching current behavior)

### Compatibility Plan

- **Backward compatibility**: N/A - UI only change
- **Default when missing**: N/A
- **Rollback strategy**: Revert QuickEntrySheet.swift changes

---

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` | Refactor `dueDateRow` (iOS) and macOS form due date section |

### Implementation Notes

**Expected Pattern (Apple HIG compliant):**
```swift
private var dueDateRow: some View {
  VStack(alignment: .leading, spacing: 0) {
    // Row 1: Label + Toggle (toggle never moves)
    HStack {
      Text("Due Date")
      Spacer()
      Toggle("", isOn: $hasDueDate)
        .labelsHidden()
    }
    // Row 2: DatePicker appears below when toggled ON
    if hasDueDate {
      DatePicker("", selection: $dueDate, displayedComponents: [.date])
        .datePickerStyle(.graphical)  // Inline calendar
        .labelsHidden()
    }
  }
}
```

**Context7 Recommended**: Query SwiftUI documentation for:
- `DatePicker` with `.graphical` style behavior
- Platform-specific date picker rendering (iOS vs macOS)

---

### Ownership

- **feature-owner**: Refactor due date UI in QuickEntrySheet.swift for all platforms
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: DatePicker graphical style inline calendar iOS macOS
CONTEXT7_TAKEAWAYS:
- Use `.datePickerStyle(.graphical)` to display an interactive calendar interface
- Available on iOS 14.0+, iPadOS 14.0+, macOS 10.15+
- Graphical style shows a full calendar view for browsing days
- The DatePicker should have `displayedComponents: [.date]` for date-only selection
- Apply the style modifier directly to the DatePicker
CONTEXT7_APPLIED:
- `.datePickerStyle(.graphical)` -> QuickEntrySheet.swift `dueDateRow` (iOS) and macOS form section

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| DatePicker graphical style inline calendar iOS macOS | `.datePickerStyle(.graphical)` with `displayedComponents: [.date]` |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-21 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The implementation correctly addresses the HIG violation. The toggle now remains stationary in a fixed VStack row while the graphical DatePicker appears below when toggled ON. This matches Apple's own pattern in Calendar.app and Reminders.app.

Both platforms (iOS and macOS) follow the same pattern with appropriate platform-specific adaptations (LabeledContent on macOS, standard Form row on iOS).

The `.graphical` DatePicker style provides an inline calendar that users expect on iOS. No extraneous UI elements. Ship it.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
