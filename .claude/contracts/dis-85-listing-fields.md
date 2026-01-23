## Interface Lock

**Feature**: DIS-85 - Add Listing Creation Fields
**Created**: 2026-01-22
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
| 1.5 | Schema ready | data-integrity |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Exploration Summary

**Existing State (fields already available in AddListingSheet):**
- Address (line 70, 114-125)
- City (line 71, 127-132)
- Province (line 72, 127-132)
- Listing Type (line 73, 134-143)
- Owner (line 74, 145-168)

**Database Schema (`listings` table) - Already exists:**
- `address` (text, required)
- `city` (text, nullable, default '')
- `province` (text, nullable, default '')
- `listing_type` (text, nullable, default 'sale')
- `listing_type_id` (uuid, FK to listing_types)

**Database Schema (`notes` table) - Polymorphic:**
- Notes are stored in separate `notes` table with `parent_type = 'listing'` and `parent_id`
- The `Listing` model already has `@Relationship var notes = [Note]()`

**What's Missing:**
1. `real_dirt` field - does NOT exist in schema, DTO, or model
2. Initial note creation - Notes exist via relationship but are not collected during listing creation

### Contract

- New/changed model fields:
  - `Listing.realDirt: String?` (new)
- DTO/API changes:
  - `ListingDTO.realDirt` (new, snake_case: `real_dirt`)
  - `ListingSyncHandler` - encode/decode realDirt
- State/actions added: None
- Migration required: Y (additive - new nullable column `real_dirt`)

### Acceptance Criteria (3 max)

1. AddListingSheet includes "Real Dirt" text field; value persists to database on save
2. AddListingSheet includes "Notes" text field; creates initial Note record linked to new listing
3. Build passes on iOS + macOS; existing listing sync functionality unaffected

### Non-goals (prevents scope creep)

- No editing of existing listings (Edit flow is separate feature)
- No changes to ListingDetailView display of real_dirt (can be added later)
- No changes to FABMenu behavior (already triggers AddListingSheet correctly)
- No changes to existing fields (address, city, province, type already work)

### Compatibility Plan

- **Backward compatibility**: `real_dirt` is nullable with no default; existing listings unaffected
- **Default when missing**: `nil` / empty string
- **Rollback strategy**: Column is nullable, can be ignored by older clients; drop column if needed

---

### Files to Modify

**Schema (data-integrity):**
- Supabase migration: add `real_dirt TEXT` column to `listings` table

**Swift (feature-owner):**
- `/Users/noahdeskin/conductor/workspaces/dispatch/kabul/Dispatch/Features/Listings/Models/Listing.swift`
  - Add `var realDirt: String?`
- `/Users/noahdeskin/conductor/workspaces/dispatch/kabul/Dispatch/Foundation/Networking/Supabase/DTOs/ListingDTO.swift`
  - Add `realDirt` field with CodingKey `real_dirt`
  - Update `toModel()` to map field
- `/Users/noahdeskin/conductor/workspaces/dispatch/kabul/Dispatch/Foundation/Persistence/Sync/Handlers/ListingSyncHandler.swift`
  - Encode `realDirt` when syncing to Supabase
- `/Users/noahdeskin/conductor/workspaces/dispatch/kabul/Dispatch/Features/Listings/Views/Sheets/AddListingSheet.swift`
  - Add `@State private var realDirt = ""`
  - Add `@State private var initialNote = ""`
  - Add form sections for Real Dirt and Notes
  - Create Note record in `saveAndDismiss()` if initialNote is not empty

**Tests (feature-owner):**
- Update `DTOTests.swift` if Listing DTO tests exist
- Verify `ListingSyncHandlerTests.swift` still passes

---

### Ownership

- **feature-owner**: End-to-end implementation (model, DTO, sync handler, UI, tests)
- **data-integrity**: Schema migration for `real_dirt` column
- **jobs-critic**: Design review of updated AddListingSheet UI
- **ui-polish**: Final UI refinements after SHIP YES
- **integrator**: Final verification (builds, tests, contract attestations)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftUI Form with TextField for multi-line text input using TextEditor or axis vertical
CONTEXT7_TAKEAWAYS:
- Use `TextField("Notes", text: $notes, axis: .vertical)` for expandable multi-line input
- Apply `.lineLimit(1...5)` to control min/max lines before scrolling
- Available in iOS 16.0+, macOS 13.0+
- Works within Form context for consistent styling
CONTEXT7_APPLIED:
- `TextField(..., axis: .vertical).lineLimit(1...5)` -> AddListingSheet.swift for realDirt and initialNote fields

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| SwiftUI Form with TextField for multi-line text input | `TextField(..., axis: .vertical).lineLimit(1...5)` for expandable text areas |

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

The new Real Dirt and Notes sections integrate cleanly with the existing form structure:

**What works well:**
- Expandable text fields (`axis: .vertical`, `lineLimit(1...5)`) start compact and grow on demand
- Optional fields placed last in form flow, reducing friction for quick entry
- Placeholder text is specific and helpful ("Insider info, history, quirks...")
- Consistent section header styling with existing sections
- No custom UI - pure native Form/Section/TextField patterns

**Minor observation (not blocking):**
- Form now has 6 sections which is approaching the upper limit of comfortable scrolling, but the logical grouping (required -> optional) keeps it manageable

The implementation follows platform conventions, uses design system tokens appropriately, and maintains the "Add" button as the clear primary action. Would Apple ship this form? Yes.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
