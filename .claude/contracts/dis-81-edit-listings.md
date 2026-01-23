## Interface Lock

**Feature**: DIS-81: Add ability to edit listings
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

- New/changed model fields: None (editing existing Listing fields)
- DTO/API changes: None (ListingDTO already supports all fields)
- State/actions added: `showEditListingSheet` state in ListingDetailView
- Migration required: N

### Acceptance Criteria (3 max)

1. User can tap "Edit Listing" from detail view overflow menu and see an edit sheet
2. Edit sheet displays all editable fields (address, city, province, postal code, price, MLS number, type, owner, due date) pre-populated with current values
3. Saving changes persists to local store, marks entity pending, and triggers sync

### Non-goals (prevents scope creep)

- No inline editing on detail view (uses sheet pattern like EditRealtorSheet)
- No validation beyond what AddListingSheet does (address required, type/owner required)
- No undo support (can be added in future ticket)
- No editing of system-managed fields (createdAt, updatedAt, createdVia, etc.)

### Compatibility Plan

- **Backward compatibility**: N/A (no DTO changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert EditListingSheet.swift and ListingDetailView changes

---

### Ownership

- **feature-owner**: Create EditListingSheet mirroring AddListingSheet patterns; wire up edit action in ListingDetailView overflow menu
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Notes

**Existing Patterns to Follow:**

1. **EditRealtorSheet.swift** - Template for edit sheet structure:
   - Init takes entity, populates `@State` fields
   - StandardScreen wrapper with Form
   - Cancel/Save toolbar buttons
   - Save updates entity, calls `markPending()`, triggers `syncManager.requestSync()`

2. **AddListingSheet.swift** - Form sections to mirror:
   - Address section (required field)
   - Location section (city, province)
   - Type section (Picker with ListingTypeDefinition)
   - Owner section (Picker with realtors)

3. **ListingDetailView.swift** - Entry point at line 178:
   - `listingActions` array has "Edit Listing" action with placeholder
   - Wire to `showEditListingSheet` state and `.sheet()` modifier

**Additional Fields for Edit (beyond AddListingSheet):**
- `postalCode`, `country` (location section)
- `price`, `mlsNumber` (new section or expand location)
- `dueDate` (date picker)

**Context7 Recommended For:**
- SwiftUI DatePicker patterns (for dueDate)
- Decimal input handling (for price field)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftUI Form DatePicker TextField patterns for edit sheet
CONTEXT7_TAKEAWAYS:
- TextField can bind to value with ParseableFormatStyle (e.g., `.currency(code:)`)
- DatePicker takes `selection: Binding<Date>` with `displayedComponents`
- For optional Date, need to use Toggle + conditional DatePicker pattern
- Form sections group related fields logically
CONTEXT7_APPLIED:
- TextField with `.currency` format -> EditListingSheet.swift:113 (price field)
- DatePicker with date-only components -> EditListingSheet.swift:156-161 (dueDate field)

CONTEXT7_QUERY: optional Date binding DatePicker nil handling toggle
CONTEXT7_TAKEAWAYS:
- DatePicker requires non-optional Binding<Date>
- Use separate Bool state to track if date is set
- Show/hide DatePicker based on toggle state
CONTEXT7_APPLIED:
- Toggle + conditional DatePicker -> EditListingSheet.swift dueDateSection

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Form DatePicker TextField patterns | TextField with ParseableFormatStyle for currency, DatePicker with displayedComponents |
| Optional Date binding handling | Toggle + hasDueDate Bool state with conditional DatePicker |

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

**Consistency**: EditListingSheet perfectly mirrors AddListingSheet form structure while appropriately extending it with edit-specific fields (price, MLS number, postal code, country, due date). The sheet follows the established EditRealtorSheet pattern for edit sheets: init with @State population, StandardScreen wrapper, Cancel/Save toolbar, markPending() + requestSync() save flow.

**Design System Compliance**: Uses DS.Colors.destructive for required field indicator, DS.Colors.Text.secondary for read-only states, DS.Icons.Action.edit for menu integration.

**Native Patterns**: Standard SwiftUI Form with .formStyle(.grouped), menu-style Pickers, standard DatePicker with toggle for optional date - all platform-idiomatic.

**Detail View Integration**: Clean integration via overflow menu using design system icon, proper sheet state management.

No changes required. Ready for integrator verification.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
