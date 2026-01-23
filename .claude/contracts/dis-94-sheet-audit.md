## Interface Lock

**Feature**: DIS-94 - Audit and Redesign All Sheets with Design System Components
**Created**: 2026-01-23
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - multiple platforms, modal interactions
- [x] **Unfamiliar area** (adds dispatch-explorer) - many sheets across different features

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Validation | xcode-pilot |

---

### Scope Summary

**Sheets Identified (from audit):**

1. **QuickEntrySheet** (`Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift`)
   - Used for: Add Task, Add Activity
   - Current state: Has platform-specific forms (iOS Form vs macOS VStack), uses DS tokens
   - Issues: macOS form uses LabeledContent pattern, iOS uses Form sections - inconsistent

2. **AddListingSheet** (`Dispatch/Features/Listings/Views/Sheets/AddListingSheet.swift`)
   - Used for: Creating new listings
   - Current state: Uses NavigationStack + Form, no StandardScreen wrapper
   - Issues: Not using StandardScreen, inconsistent with EditListingSheet

3. **EditListingSheet** (`Dispatch/Features/Listings/Views/Sheets/EditListingSheet.swift`)
   - Used for: Editing existing listings
   - Current state: Uses StandardScreen + Form
   - Issues: Good baseline pattern to follow

4. **AddSubtaskSheet** (`Dispatch/Features/WorkItems/Views/Sheets/AddSubtaskSheet.swift`)
   - Used for: Adding subtasks
   - Current state: Simple NavigationStack + Form, minimal
   - Issues: Not using StandardScreen, very basic

5. **EditRealtorSheet** (`Dispatch/Features/Realtors/Views/Screens/EditRealtorSheet.swift`)
   - Used for: Add/Edit realtors
   - Current state: Uses StandardScreen + Form
   - Issues: Good baseline pattern

6. **MultiUserPicker (in sheet context)** (`Dispatch/SharedUI/Components/MultiUserPicker.swift`)
   - Used for: Assignee selection (wrapped in sheets by parent views)
   - Current state: Custom VStack-based list, not using Form
   - Issues: Wrapped inconsistently by different parents (some use NavigationStack, sizing varies)

7. **Listing Picker (inline in QuickEntrySheet)**
   - Used for: Selecting listing association
   - Current state: Inline List in QuickEntrySheet
   - Issues: Could be extracted to reusable component

**Patterns to Standardize:**

| Pattern | Current | Target |
|---------|---------|--------|
| Sheet wrapper | Mixed (NavigationStack, StandardScreen) | StandardScreen with `scroll: .disabled` for forms |
| Toolbar pattern | Cancel left, Confirm right | Standardize with `.cancellationAction` / `.confirmationAction` |
| Presentation detents | Mixed (.medium, .large, none) | Platform-specific: iOS uses detents, macOS uses frame sizing |
| Form sections | Inconsistent grouping | Follow Apple HIG grouped form pattern |
| Title display mode | Some `.inline`, some missing | Always `.inline` for sheets on iOS |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (possible new SheetState cases if needed)
- Migration required: N

### Acceptance Criteria (3 max)

1. **All sheets use consistent DS components**: Every sheet uses StandardScreen (or a new StandardSheet wrapper), DS.Typography, DS.Spacing, DS.Colors - no hardcoded values
2. **Cross-platform consistency**: All sheets render correctly on iOS, iPadOS, and macOS with appropriate platform adaptations (detents on iOS, frame sizing on macOS)
3. **Picker sheets extracted**: MultiUserPicker and ListingPicker have standardized sheet wrappers that can be reused across the app

### Non-goals (prevents scope creep)

- No new sheet functionality (only visual/structural consistency)
- No changes to sheet business logic or data flow
- No new sheet types beyond what currently exists
- No changes to when/how sheets are triggered (SheetState enum unchanged unless absolutely necessary)

### Compatibility Plan

- **Backward compatibility**: N/A - pure UI refactor
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit(s) - no data changes involved

---

### Ownership

- **feature-owner**: End-to-end sheet redesign across all platforms
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Notes

**Recommended approach (phased):**

**Phase 1: Create StandardSheet component (if needed)**
- Evaluate if StandardScreen with `scroll: .disabled` is sufficient
- Or create `StandardSheet` wrapper that handles common sheet patterns (NavigationStack, toolbar, detents)

**Phase 2: Audit and update each sheet**
- Start with AddListingSheet (simplest, good test case)
- Move to AddSubtaskSheet
- Then QuickEntrySheet (most complex, platform-specific)
- Finally picker sheets (MultiUserPicker wrapper, ListingPicker extraction)

**Phase 3: Verify cross-platform behavior**
- Test all sheets on iPhone, iPad, macOS
- Verify presentation detents work correctly
- Verify keyboard avoidance on iOS
- Verify sizing on macOS

**Context7 Recommended Queries:**
- SwiftUI: Sheet presentation and detents best practices
- SwiftUI: Form styling and grouped form patterns
- Apple HIG: Modal sheet guidelines

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Form inside NavigationStack with grouped style and toolbar for sheets
CONTEXT7_TAKEAWAYS:
- Use `.formStyle(.grouped)` modifier to get visually grouped sections with leading labels
- Form renders platform-appropriately (pickers show different UIs on iOS vs macOS)
- Form is ideal for data-entry interfaces, settings, and preference screens
CONTEXT7_APPLIED:
- `.formStyle(.grouped)` -> AddListingSheet.swift:117, AddSubtaskSheet.swift:35

CONTEXT7_QUERY: sheet presentationDetents medium large and toolbar placement cancellationAction confirmationAction
CONTEXT7_TAKEAWAYS:
- Use `.presentationDetents([.medium, .large])` for resizable sheets
- `.cancellationAction` placement puts Cancel on leading edge (iOS) or trailing before confirm (macOS)
- `.confirmationAction` placement puts the primary confirm button appropriately per platform
- Toolbar items inside NavigationStack work well with sheets
CONTEXT7_APPLIED:
- `.presentationDetents([.medium, .large])` -> AddListingSheet.swift:54, AddSubtaskSheet.swift:53

CONTEXT7_QUERY: Form grouped style with platform-specific appearance iOS macOS LabeledContent for data entry forms
CONTEXT7_TAKEAWAYS:
- Form automatically applies platform-appropriate styling to controls
- `.formStyle(.grouped)` creates visually grouped sections with leading labels and trailing controls
- Forms appear as grouped lists on iOS, aligned vertical stacks on macOS
- Picker control in Form shows navigation on iOS, pop-up on macOS
CONTEXT7_APPLIED:
- Unified Form with `.formStyle(.grouped)` -> QuickEntrySheet.swift:137 (replaced platform-specific code)

CONTEXT7_QUERY: List Section ForEach picker sheet selection checkmark multi-select pattern
CONTEXT7_TAKEAWAYS:
- Bind to `Set` of IDs for multi-selection in List
- Use button with checkmark for custom selection UI
- `.listStyle(.plain)` for simple list appearance in sheets
- Custom row with selection state provides more control than built-in selection
CONTEXT7_APPLIED:
- List with custom selection buttons -> MultiUserPicker.swift:36, StandardListingPickerSheet.swift:42

---

### Context7 Attestation (written by feature-owner at PATCHSET 1, updated at PATCHSET 2)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Form inside NavigationStack with grouped style and toolbar for sheets | `.formStyle(.grouped)` for grouped sections |
| sheet presentationDetents medium large and toolbar placement | `.presentationDetents([.medium, .large])`, `.cancellationAction` / `.confirmationAction` placements |
| Form grouped style with platform-specific appearance | Unified Form with `.formStyle(.grouped)` replaces platform-specific code |
| List Section ForEach picker sheet selection checkmark | List with custom selection buttons for picker sheets |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-23 (Patchset 2.5)

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

All five sheets reviewed meet the design bar:

**1. AddListingSheet.swift** - PASS
- StandardScreen with scroll disabled (correct for forms)
- Form with .formStyle(.grouped) for native appearance
- Clear Cancel/Add toolbar pattern
- Loading state handled cleanly with ProgressView
- DS tokens used throughout

**2. AddSubtaskSheet.swift** - PASS
- Model of minimal simplicity - single text field
- StandardScreen wrapper correctly applied
- Cancel/Add toolbar with proper disabled state
- Nothing can be removed - exemplary sheet

**3. QuickEntrySheet.swift** - PASS
- Handles complexity through progressive disclosure
- Unified Form with .formStyle(.grouped)
- Picker buttons use consistent row pattern with chevron
- Accessibility labels and hints present
- Sub-sheets use standardized wrappers

**4. MultiUserPicker + MultiUserPickerSheet** - PASS
- Clean list with checkmark selection (native pattern)
- Current user sorted to top with "You" label
- StandardScreen wrapper with "Done" button (appropriate for multi-select)
- Platform-appropriate sizing (iOS detents, macOS frame)
- ScaledMetric for Dynamic Type support

**5. StandardListingPickerSheet** - PASS
- "None" option at top for deselection
- Cancel button only - selections are immediate (correct pattern)
- Clear information hierarchy (address + city)
- Accessibility traits applied (.isSelected)

**Execution Summary:**
- DS Components: All sheets use StandardScreen, DS.Typography, DS.Spacing, DS.Colors
- SF Symbols: checkmark, Navigation.forward icons confirmed
- Touch targets: DS.Spacing.minTouchTarget (44pt) applied
- Accessibility: Dynamic Type, VoiceOver labels, contrast all good

**Optional refinements for ui-polish:**
1. AddListingSheet: Consider deferring "Required" message until after first interaction
2. QuickEntrySheet: DatePicker graphical style could be compact for less visual weight
3. All sheets: Verify keyboard avoidance during xcode-pilot validation

---

### Files to Modify

```
Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift
Dispatch/Features/WorkItems/Views/Sheets/AddSubtaskSheet.swift
Dispatch/Features/Listings/Views/Sheets/AddListingSheet.swift
Dispatch/Features/Listings/Views/Sheets/EditListingSheet.swift (baseline, may need minor updates)
Dispatch/Features/Realtors/Views/Screens/EditRealtorSheet.swift (baseline, may need minor updates)
Dispatch/SharedUI/Components/MultiUserPicker.swift (or new wrapper)
Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift (picker sheet standardization)
Dispatch/Features/WorkItems/Views/Components/WorkItem/WorkItemDetailView.swift (picker sheet standardization)
```

Estimated file count: 8-12 files (exceeds 3-file bypass threshold)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
