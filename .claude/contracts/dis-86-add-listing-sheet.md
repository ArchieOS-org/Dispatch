## Interface Lock

**Feature**: Redesign Add Listing Sheet with Proper Design System
**Issue**: DIS-86
**Created**: 2026-01-22
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

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Problem Statement

The current `AddListingSheet.swift` has the following issues:
1. **Wrong padding**: Uses raw `Form {}` without design system spacing tokens
2. **Bad macOS appearance**: No platform-specific form layout (iOS Form looks wrong on Mac)
3. **Wrong spacing**: Inconsistent with design system (`DS.Spacing.*`)
4. **No shared pattern**: `QuickEntrySheet` has separate iOS/macOS layouts but they're not extracted into a reusable component

### Current State Analysis

**AddListingSheet.swift (258 lines)**:
- Uses SwiftUI `Form {}` directly (no DS tokens for spacing/padding)
- Only iOS-specific: `#if os(iOS)` for `.presentationDetents` and `.navigationBarTitleDisplayMode`
- No macOS-specific layout (falls through to iOS Form, which looks wrong)
- 6 sections: address, location, type, owner, realDirt, notes

**QuickEntrySheet.swift (536 lines)** - Better pattern:
- Has `#if os(macOS)` with `VStack + LabeledContent` layout
- Has `#if !os(macOS)` with iOS `Form` layout
- Uses DS tokens: `DS.Spacing.*`, `DS.Colors.*`, `DS.Typography.*`, `DS.Icons.*`
- Has min touch targets: `frame(minHeight: DS.Spacing.minTouchTarget)`

### Proposed Solution

Create a shared sheet foundation that can be used by:
1. AddListingSheet
2. QuickEntrySheet (Task/Activity creation)
3. Future entity creation sheets

**New Shared Component**: `FormSheet` or similar wrapper that:
- Provides platform-adaptive layout (VStack+LabeledContent on Mac, Form on iOS)
- Enforces DS spacing tokens
- Handles `.presentationDetents` and navigation title display mode
- Provides consistent toolbar pattern (Cancel/Add or Cancel/Save)

### Acceptance Criteria (3 max)

1. **Cross-platform consistency**: AddListingSheet renders correctly on iOS, iPadOS, AND macOS with platform-appropriate layouts (Form on iOS/iPad, VStack+LabeledContent on Mac)
2. **Design system compliance**: All spacing uses DS.Spacing tokens, all colors use DS.Colors tokens, all typography uses DS.Typography tokens
3. **Shared pattern extracted**: Create a reusable sheet layout component in `Dispatch/Design/Shared/Components/` that AddListingSheet and QuickEntrySheet can both use

### Non-goals (prevents scope creep)

- No changes to AddListingSheet business logic or validation
- No changes to what fields are displayed (address, city, province, type, owner, realDirt, notes stay the same)
- No new navigation flows
- Refactoring QuickEntrySheet to use the new shared pattern is OPTIONAL (can be follow-up)

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only, no data changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit

---

### Technical Approach

1. **Create shared component**: `Dispatch/Design/Shared/Components/FormSheetContainer.swift`
   - Platform-adaptive wrapper
   - Consistent toolbar handling
   - DS token enforcement via child content constraints

2. **Update DESIGN_SYSTEM.md**: Document the new FormSheetContainer component with usage examples

3. **Refactor AddListingSheet**:
   - Use FormSheetContainer
   - Add `#if os(macOS)` section with VStack+LabeledContent layout
   - Apply DS.Spacing tokens throughout
   - Ensure minTouchTarget on interactive elements

### Files to Modify

| File | Change |
|------|--------|
| `Dispatch/Design/Shared/Components/FormSheetContainer.swift` | NEW - Shared sheet wrapper |
| `Dispatch/Features/Listings/Views/Sheets/AddListingSheet.swift` | Refactor to use shared pattern |
| `DESIGN_SYSTEM.md` | Document FormSheetContainer |

### Implementation Notes

**Context7 Recommended For**:
- SwiftUI Form and LabeledContent best practices
- macOS vs iOS sheet presentation differences
- Accessibility requirements for form fields

---

### Ownership

- **feature-owner**: End-to-end implementation of FormSheetContainer and AddListingSheet refactor
- **data-integrity**: Not needed
- **jobs-critic**: Review design bar compliance at PATCHSET 2.5
- **ui-polish**: Refine spacing, typography, platform polish at PATCHSET 2.5

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Form LabeledContent platform adaptive layout macOS iOS
CONTEXT7_TAKEAWAYS:
- Form struct acts as container for grouping UI controls with platform-appropriate layout
- LabeledContent associates labels with custom views in forms
- Layout of controls inside Form differs significantly based on platform (iOS navigation pickers vs macOS popups)
- TextField and SecureField use prompt parameter for placeholder text
- Form automatically applies platform-appropriate styling to children
CONTEXT7_APPLIED:
- Platform-adaptive Form/VStack pattern -> FormSheetContainer.swift:46-65

CONTEXT7_QUERY: LabeledContent styling label format custom alignment
CONTEXT7_TAKEAWAYS:
- LabeledContent init(_:value:format:) creates labeled views with FormatStyle
- Can use custom @ViewBuilder content for complex values
- Labels align automatically in Form context
CONTEXT7_APPLIED:
- LabeledContent with custom content -> FormSheetRow, FormSheetPickerRow

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| Form LabeledContent platform adaptive layout macOS iOS | Platform-adaptive Form (iOS) vs VStack+LabeledContent (macOS) |
| LabeledContent styling label format custom alignment | LabeledContent with @ViewBuilder content for form rows |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

Platform-adaptive form sheet implementation meets all design bar criteria:

**Strengths:**
- FormSheetContainer provides clean abstraction for iOS (Form) vs macOS (VStack+LabeledContent)
- All spacing uses DS.Spacing tokens (lg, xl, sm, xs, md, minTouchTarget)
- All typography uses DS.Typography tokens (headline, body, caption)
- All colors use DS.Colors tokens (Text.primary, Text.secondary, Text.tertiary, destructive)
- Loading, empty, and validation states all handled cleanly
- Touch targets meet 44pt minimum
- Proper toolbar placements (.cancellationAction, .confirmationAction)

**Execution Details:**
- DS Components: FormSheetContainer, FormSheetSection, FormSheetRow, FormSheetTextRow, FormSheetPickerRow (documented in DESIGN_SYSTEM.md)
- A11y: Dynamic Type supported via DS.Typography, LocalizedStringKey throughout, labels present
- States: Loading (ProgressView), empty (no realtors message), validation (required field errors)

**Would Apple Ship This?** Yes - follows platform conventions exactly, clean visual hierarchy, no unnecessary UI elements.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
