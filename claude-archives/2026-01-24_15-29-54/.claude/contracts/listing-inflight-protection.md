## Interface Lock

**Feature**: Listing In-Flight Protection
**Created**: 2026-01-18
**Status**: DONE
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer) - need to validate V1 assumption

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added:
  - `ConflictResolver.inFlightListingIds: Set<UUID>`
  - `ConflictResolver.markListingsInFlight(_:)`
  - `ConflictResolver.clearListingsInFlight()`
  - `ConflictResolver.isListingInFlight(_:) -> Bool`
- Migration required: N

### Acceptance Criteria (3 max)

1. ListingSyncHandler.syncUp() marks pending listings as in-flight before upsert, clears after completion (matching Task/Activity pattern)
2. ListingSyncHandler.upsertListing() passes in-flight status to ConflictResolver.isLocalAuthoritative() instead of hardcoded `false`
3. Tests verify in-flight protection prevents realtime echo overwrites during rapid listing edits

### Non-goals (prevents scope creep)

- No changes to ListingTypeDefinition sync (different entity, less user-edited)
- No changes to existing pending/failed protection logic (already works correctly)
- No changes to the upsert field mapping

### Compatibility Plan

- **Backward compatibility**: N/A - No API/DTO changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert ConflictResolver additions and ListingSyncHandler changes; existing pending/failed protection still works

---

### Technical Analysis

#### Why In-Flight Protection is Needed

**Original V1 Assumption (INCORRECT)**:
> "No inFlightListingIds needed for V1 as listings are rarely user-edited locally"

**Evidence Contradicting This**:
1. `AddListingSheet.swift:205` - Users create new listings locally
2. `ListingDetailView.swift:198` - Users change listing stage locally
3. `ListingDetailView.swift:381` - Users soft-delete listings locally
4. `ListingListView.swift:289` - Users delete listings locally

**The Race Condition**:
Without in-flight protection, the following can occur:
1. User edits listing locally -> listing.syncState = .pending
2. syncUp() starts -> batch upsert sent to Supabase
3. Supabase realtime broadcasts the change back (echo)
4. Realtime handler receives echo, calls upsertListing()
5. By this time, listing.syncState = .synced (just marked)
6. isLocalAuthoritative returns FALSE (synced + inFlight=false)
7. Remote echo OVERWRITES the local edit with stale data

**Why Task/Activity Have Protection**:
TaskSyncHandler and ActivitySyncHandler mark IDs as in-flight before syncUp and check during upsertTask/upsertActivity. This prevents step 6-7 from occurring.

---

### Ownership

- **feature-owner**: Implement in-flight protection in ConflictResolver and ListingSyncHandler
- **data-integrity**: Not needed (no schema changes)

---

### Files to Modify

1. `/Dispatch/Foundation/Persistence/Sync/ConflictResolver.swift`
   - Add `inFlightListingIds: Set<UUID>`
   - Add `markListingsInFlight(_:)`, `clearListingsInFlight()`, `isListingInFlight(_:)`
   - Update `clearAllInFlight()` to include listings

2. `/Dispatch/Foundation/Persistence/Sync/Handlers/ListingSyncHandler.swift`
   - In `syncUp()`: Mark pending listing IDs as in-flight before upsert, defer clear
   - In `upsertListing()`: Replace `inFlight: false` with `inFlight: dependencies.conflictResolver.isListingInFlight(existing.id)`
   - Remove/update the V1 comment

3. `/DispatchTests/ListingSyncHandlerTests.swift`
   - Update `test_upsertListing_noInFlightProtectionForListings` -> `test_upsertListing_withInFlightProtection`
   - Add test for in-flight protection skipping remote updates
   - Add test for in-flight cycle (mark -> check -> clear)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A - This is internal sync logic, no external framework patterns needed

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

This is a pure internal refactor following existing codebase patterns (TaskSyncHandler, ActivitySyncHandler). No external framework/library patterns needed.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

UI Review Required: NO - This is backend sync logic with no UI changes.

---

### Integrator Verification (PATCHSET 2 - Final)

**Verified**: 2026-01-18
**Verifier**: integrator

| Check | Result |
|-------|--------|
| Build iOS Simulator | PASS |
| Build macOS | PASS |
| Tests (604 total, 591 passed, 13 skipped) | PASS |
| SwiftLint --strict | PASS (0 violations) |
| SwiftFormat --lint | PASS (gitignored Secrets.swift excluded) |
| UI Review Required: NO | Jobs Critique skipped |
| Context7 Attestation: N/A | Valid for internal refactor |

**Acceptance Criteria Verified**:
1. `ListingSyncHandler.syncUp()` marks/clears in-flight (lines 81-82) - VERIFIED
2. `ListingSyncHandler.upsertListing()` uses `isListingInFlight()` (line 138) - VERIFIED
3. Tests cover in-flight protection scenarios - VERIFIED (lines 315-565)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: N/A is valid for pure internal refactors following existing codebase patterns
