## Interface Lock

**Feature**: DIS-88 Default Listing Selection to Current Listing
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer) - Already explored

### Patchset Plan

Based on checked indicators (standard 2-patchset, no schema/complex UI):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: Extend `AppState.SheetState.quickEntry` case with `preselectedListingId: UUID?` associated value
- Migration required: N

### Technical Approach

1. **Extend SheetState enum** (`AppState.swift:56`):
   - Change `.quickEntry(type: QuickEntryItemType?)` to `.quickEntry(type: QuickEntryItemType?, preselectedListingId: UUID?)`
   - Update Equatable conformance to compare both values

2. **Update all quickEntry callsites** (add `preselectedListingId: nil` to existing calls):
   - `GlobalFloatingButtons.swift:85,87` - FAB menu actions
   - `MacContentView.swift:150` - handleNew()
   - `iPadContentView.swift:68,70` - iPad FAB menu
   - `AppState.swift:208` - .newItem command

3. **Update sheet content routing** to pass preselectedListingId to QuickEntrySheet:
   - `iPhoneContentView.swift:124-131` - sheetContent(for:)
   - `MacContentView.swift:174-181` - sheetContent(for:)

4. **Add QuickEntrySheet init param and onAppear logic** (`QuickEntrySheet.swift`):
   - Add `preselectedListingId: UUID?` parameter to init
   - In onAppear/task, find listing by ID from listings array and set selectedListing

5. **Add action buttons in ListingDetailView** (`ListingDetailView.swift`):
   - Add "Add Task" and "Add Activity" to listingActions array
   - Trigger `.quickEntry(type: .task, preselectedListingId: listing.id)` etc.

### Files to Modify (6 files)

| File | Change |
|------|--------|
| `Dispatch/App/State/AppState.swift` | Extend SheetState.quickEntry with preselectedListingId |
| `Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` | Add preselectedListingId param, onAppear logic |
| `Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift` | Add task/activity creation actions |
| `Dispatch/App/Platform/iPhoneContentView.swift` | Update sheetContent routing |
| `Dispatch/App/Platform/MacContentView.swift` | Update sheetContent routing |
| `Dispatch/App/Platform/iPadContentView.swift` | Add sheet handling if missing |
| `Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | Update callsites with nil |

### Acceptance Criteria (3 max)

1. When on ListingDetailView, "Add Task" or "Add Activity" action opens QuickEntrySheet with listing pre-selected
2. Existing quickEntry flows (FAB, toolbar) continue to work with no listing pre-selected
3. Builds on iOS and macOS without warnings

### Non-goals (prevents scope creep)

- No changes to the listing picker itself (existing picker UI is fine)
- No default selection for realtors, properties, or other contexts
- No persistence of last-selected listing across sessions

### Compatibility Plan

- **Backward compatibility**: N/A - internal state only, no API/DTO
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit - no data changes

---

### Ownership

- **feature-owner**: Extend SheetState, update all callsites, add QuickEntrySheet param and logic, add ListingDetailView actions
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A - Pure state-passing refactor with no new framework patterns

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A | N/A - Pure enum extension and state passing, no new framework patterns. Uses existing `.task` modifier (standard SwiftUI) for one-time initialization. |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

#### Checklist

N/A - UI Review Required: NO (no new UI, no navigation changes, uses existing sheet and picker)

#### Verdict Notes

Not applicable. This feature modifies internal state passing only. The QuickEntrySheet UI and listing picker remain unchanged. The only user-visible change is listing pre-selection when triggered from ListingDetailView.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
