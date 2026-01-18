## Interface Lock

**Feature**: Realtor Profile View Restructure
**Created**: 2025-01-15
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

### Contract
- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- UI events emitted: None
- Migration required: N

### UI Changes (scope)
1. Move title (user name) below avatar image instead of navigation title
2. Increase avatar size from 80pt to 120pt
3. Reorder sections: Active Listings ABOVE Properties
4. Remove count from section headers ("Properties" not "Properties (X)")
5. Change status tag to use `listing.stage` (ListingStage enum) instead of `listing.status`
6. Remove leading icons from PropertyRowView and ListingRowView

### Files Modified
- `Dispatch/Features/Realtors/Views/Screens/RealtorProfileView.swift` (single file)

### Acceptance Criteria (3 max)
1. Avatar displays at 120pt with user name centered below it (not in nav bar)
2. Active Listings section appears before Properties section, both without counts
3. Listing status tags show correct stage values: Pending, Working On, Live, Sold, Re-List, or Done

### Non-goals (prevents scope creep)
- No changes to navigation structure
- No changes to data fetching or filtering logic
- No changes to Recent Activity section
- No new screens or modals
- No changes to EditRealtorSheet

### Compatibility Plan
- **Backward compatibility**: N/A (UI-only changes)
- **Default when missing**: Uses existing `listing.stage` computed property which defaults to `.pending`
- **Rollback strategy**: Revert single file

### Ownership
- **feature-owner**: Full RealtorProfileView restructure
- **data-integrity**: Not needed

### Implementation Notes
- ListingStage enum already exists at `Dispatch/Features/Listings/Models/Enums/ListingStage.swift`
- ListingStage has `displayName` property for proper formatting
- Current code uses `listing.status.rawValue.capitalized` - change to `listing.stage.displayName`

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-15 10:45

#### Checklist
- [x] Ruthless simplicity - section counts removed, icons removed from rows, clean navigation
- [x] One clear primary action - Edit button in toolbar, quick actions appropriately secondary
- [x] Strong hierarchy - 120pt avatar anchors view, name (title) below, role badge subordinate, section headers delineate
- [x] No clutter - generous DS.Spacing throughout, icon removal reduces cognitive load
- [x] Native feel - StandardScreen layout, 44pt touch targets, DS tokens used consistently

#### Verdict Notes
Clean implementation. The large avatar with centered name creates a strong personal identity anchor. Removing section counts and row icons reduces noise without losing information. All acceptance criteria met:

1. Avatar at 120pt with name below (not nav bar) - verified
2. Active Listings before Properties, no counts - verified
3. Stage displayName used (Pending, Working On, Live, Sold, Re-List, Done) - verified

DS compliance: Uses DS.Typography, DS.Colors, DS.Spacing consistently. Touch targets meet 44pt minimum. Empty states handled via conditional rendering.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
