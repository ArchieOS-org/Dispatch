## Interface Lock

**Feature**: DIS-75 Task/Activity Audience Mutual Exclusivity
**Created**: 2026-01-21
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [x] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 1.5 | Schema ready + migration | data-integrity |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Problem Analysis

**Current State:**
- `TaskItem` and `Activity` models have `audiencesRaw: [String]` which stores multiple audiences
- Default value is `["admin", "marketing"]` (both audiences)
- `audiences` computed property returns `Set<Role>` allowing multiple roles
- UI components (`ActivityTemplateEditorView`, `QuickEntrySheet`) allow selecting multiple audiences
- `AudienceLens.matches()` shows items containing that audience (admin sees admin-only + both, marketing sees marketing-only + both)

**Problem:**
- A task/activity should only be for ONE audience type, not both
- Existing data may have items marked as both `["admin", "marketing"]`
- UI allows toggling both audiences on simultaneously
- No validation prevents saving items with multiple audiences

**Affected Entities:**
1. `TaskItem` - `audiencesRaw: [String]`
2. `Activity` - `audiencesRaw: [String]`
3. `ActivityTemplate` - `audiencesRaw: [String]`

### Contract

- New/changed model fields:
  - `TaskItem.audiencesRaw` - Change default from `["admin", "marketing"]` to single value
  - `Activity.audiencesRaw` - Change default from `["admin", "marketing"]` to single value
  - `ActivityTemplate.audiencesRaw` - Already defaults to `[]`, needs validation
  - Consider: `audience: String?` (single value) vs keeping array with validation

- DTO/API changes:
  - `TaskDTO.audiences` - Validation on toModel()
  - `ActivityDTO.audiences` - Validation on toModel()
  - `ActivityTemplateDTO.audiences` - Validation

- State/actions added:
  - UI validation preventing multiple audience selection
  - Error/warning message when user tries to select both
  - Migration logic for existing conflicting data

- Migration required: **Y**
  - Data migration for existing records with multiple audiences
  - Decision needed: Default conflicting items to "admin" or "marketing"?

### Acceptance Criteria (3 max)

1. **Enforcement**: Users cannot save a task/activity/template with more than one audience selected - UI prevents this with clear feedback
2. **Migration**: Existing data with multiple audiences is migrated to a single audience (admin takes priority, as it's the more restrictive role)
3. **Sync Guard**: DTO validation rejects or normalizes records with multiple audiences during sync

### Non-goals (prevents scope creep)

- No changes to the `Role` enum or `AudienceLens` filter behavior
- No new "no audience" / "none" option (items must have exactly one audience)
- No backend/Supabase constraint (client-side enforcement only for v1)
- No changes to how the audience filter button works

### Compatibility Plan

- **Backward compatibility**: DTOs continue accepting arrays but normalize to single value
- **Default when missing**: Keep existing default behavior (fall back to admin if null/empty)
- **Rollback strategy**: No schema change to DB; all changes are client-side model defaults and validation

### Migration Strategy

**For existing conflicting data (items with both audiences):**
1. On sync-down, normalize `["admin", "marketing"]` to `["admin"]` (admin priority)
2. Log migration actions for debugging
3. Mark migrated items as pending so they sync back up with corrected value

**Decision Rationale:** Admin is chosen as the priority because:
- Admin users typically need broader visibility
- Marketing-specific items should be explicitly marketing-only
- This matches the "restrictive by default" principle

---

### Ownership

- **feature-owner**:
  - Model changes (default values, computed properties)
  - DTO validation/normalization
  - UI enforcement (ActivityTemplateEditorView, QuickEntrySheet)
  - Migration logic in sync handlers
  - Add user feedback for mutual exclusivity violation

- **data-integrity**:
  - Review migration strategy
  - Verify sync handler changes don't break existing sync flow
  - Test edge cases: empty arrays, null values, single-value arrays

---

### Files to Modify

**Models (3 files):**
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Features/WorkItems/Models/TaskItem.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Features/WorkItems/Models/Activity.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Features/Settings/Models/ActivityTemplate.swift`

**DTOs (3 files):**
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Foundation/Networking/Supabase/DTOs/TaskDTO.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Foundation/Networking/Supabase/DTOs/ActivityDTO.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Foundation/Networking/Supabase/DTOs/ActivityTemplateDTO.swift`

**UI (2 files):**
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Features/Settings/Views/ActivityTemplateEditorView.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/philadelphia-v1/Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` (if audience selection added)

**Tests (new/modified):**
- Add tests for mutual exclusivity validation
- Add tests for migration normalization

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

**PATCHSET 1**: N/A (core Swift patterns only - guard-let, array contains, literals)

**PATCHSET 2**:
CONTEXT7_QUERY: Picker selection binding mutually exclusive single choice radio button style
CONTEXT7_TAKEAWAYS:
- Use `Picker` with `$selection` binding for mutually exclusive choices
- `radioGroup` style available on macOS 10.15+ for radio button presentation
- `inline` or `menu` styles work well for iOS
- Picker ensures only one item selected at a time (mutual exclusivity built-in)
- Use enum conforming to `CaseIterable, Identifiable` for type-safe options
CONTEXT7_APPLIED:
- Enum-based AudienceSelection with CaseIterable/Identifiable -> ActivityTemplateEditorView.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| PATCHSET 1: N/A | Core Swift: guard-let unwrapping, array.contains(), array literals |
| PATCHSET 2: Picker selection binding mutually exclusive | Enum with CaseIterable/Identifiable, single-selection pattern with chips |

**Rationale**: PATCHSET 1 used only fundamental Swift syntax. PATCHSET 2 consulted SwiftUI docs for mutually exclusive selection patterns; implemented using enum-based selection with chip UI instead of Picker for better visual clarity and match with existing design system. |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**PASS - The chip-based single-selection UI is appropriate and well-executed.**

Design Strengths:
1. Three chips (None/Admin/Marketing) are minimal for the use case - no extraneous UI
2. Chips provide better visual differentiation than a Picker - Admin (blue) and Marketing (orange) colors convey meaningful context at a glance
3. Footer text "Each activity can only be visible to one audience" explains the constraint concisely
4. Checkmark indicator on selection makes state immediately clear
5. Haptic feedback on selection adds polish without intrusion
6. Uses DS components throughout: DS.Colors (info, warning, Text.tertiary), DS.Typography (body, caption), DS.Spacing

Accessibility: PASS
- accessibilityLabel, accessibilityHint, accessibilityAddTraits(.isSelected) properly set
- ScaledMetric for Dynamic Type support on checkmark icon
- Chip padding provides adequate touch targets

States Handled: PASS
- Edit existing template (loads current selection)
- Create new template (defaults to None)
- Form validation (title required, audience optional)

---

### Implementation Notes

**UI Enforcement Pattern:**
The `ActivityTemplateEditorView` already uses `AudienceToggleChip` components. The fix should:
1. Modify `toggleAudience()` to deselect the other audience when one is selected
2. Add haptic feedback or brief toast explaining "Only one audience can be selected"
3. Consider radio-button style UX instead of toggle chips for clarity

**QuickEntrySheet:**
Currently does NOT expose audience selection - items get the default audiences. Options:
1. Keep hidden, items default to single audience (e.g., admin)
2. Add audience picker (increases complexity but gives control)
Recommendation: Option 1 for v1, can expand later

**Sync Handler Migration:**
Add normalization in `toModel()` functions:
```swift
// In TaskDTO.toModel()
let normalizedAudiences = normalizeAudiences(audiences ?? ["admin"])
// Where normalizeAudiences takes first value or defaults to "admin"
```

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
