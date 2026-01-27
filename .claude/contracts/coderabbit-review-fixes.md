## Interface Lock

**Feature**: CodeRabbit Review Fixes (PR #137)
**Created**: 2026-01-27
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO (fixes are non-visual: error handling, code patterns, preview data determinism)

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer) - need to verify CodeRabbit claims

### Patchset Plan

Based on checked indicators (minimal - refactoring/fixes only):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Analysis complete | dispatch-explorer |
| 2 | Fixes complete, compiles, tests pass | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: NO

---

### CodeRabbit Review Analysis

#### Critical (1) - MUST FIX

| File | Line | Issue | Analysis | Action |
|------|------|-------|----------|--------|
| `AppDestinations.swift` | 99 | Missing `supabase` property - using undefined global | **FALSE POSITIVE**: `supabase` is a global computed property defined in `SupabaseClient.swift:59` - intentional app-wide accessor pattern. This is the established pattern in the codebase. | SKIP |

#### Major (7) - ANALYZE AND FIX VALID ISSUES

| File | Line | Issue | Analysis | Action |
|------|------|-------|----------|--------|
| `SupabaseEnvironment.swift` | 28 | Hardcoded anon key in source | **VALID CONCERN but LOCAL ONLY**: This key is for LOCAL Docker Supabase development only (comment on line 26 states this). Production uses `Secrets.supabaseAnonKey`. Not a security issue for local dev, but could add comment clarification. | DOCUMENT |
| `HistoryEntryRow.swift` | 104-121 | Task in button - potential UI freeze if restore takes long | **VALID**: Should handle long-running restore gracefully. Current code shows ProgressView during restore and disables button - this is correct. However, if the async action throws, `isRestoring` stays true. | FIX |
| `RecentlyDeletedView.swift` | 130 | `errorState(_:)` has unused parameter | **VALID**: Parameter `error` is unused but available. Should either use it or keep as `_` for clarity. Currently shows generic "Failed to load" without error details. | FIX |
| `ListingDetailView.swift` | 237-244 | Using global `supabase` in HistorySection | **FALSE POSITIVE**: Same pattern as Critical #1. Global `supabase` is intentional. | SKIP |
| `PropertyDetailView.swift` | 92-99 | Using global `supabase` in HistorySection | **FALSE POSITIVE**: Same pattern as Critical #1. Global `supabase` is intentional. | SKIP |
| `RealtorProfileView.swift` | 170-177 | Using global `supabase` in HistorySection | **FALSE POSITIVE**: Same pattern as Critical #1. Global `supabase` is intentional. | SKIP |
| `AuditEntry.swift` | multiple | Preview mocks use `Date()` - non-deterministic | **VALID**: Preview data should be deterministic for snapshot testing and consistent preview rendering. | FIX |

#### Minor (9) - FIX IF GOOD ROI

| File | Line | Issue | Analysis | Action |
|------|------|-------|----------|--------|
| Various | - | PreviewShell wrappers should use deterministic data | **VALID**: Some previews create data with non-deterministic IDs or dates | PARTIAL FIX |
| `PropertyDetailView.swift` | 255-259 | DateFormatter created on each call in PropertyListingRow | **VALID**: Can cache formatter as static property | FIX |
| Contract docs | - | Missing Context7 attestation sections | **VALID**: Ensure contract template compliance | SKIP (already done) |

#### Trivial (9) - SKIP UNLESS TRIVIALLY EASY

| Category | Issue | Action |
|----------|-------|--------|
| Code duplication | Similar empty state patterns | SKIP - shared via DS components |
| Wording | Minor copy suggestions | SKIP |
| Imports | Unused import suggestions | SKIP - handled by lint |

---

### Acceptance Criteria (3 max)

1. **Error handling improved**: `HistoryEntryRow` restore button properly resets `isRestoring` on error; `RecentlyDeletedView` error state shows actionable info
2. **Preview determinism**: Mock audit entries use fixed dates relative to a stable reference; preview data uses consistent timestamps
3. **Performance micro-fix**: `PropertyListingRow.formatDate` caches DateFormatter as static property

---

### Non-goals (prevents scope creep)

- No refactoring of global `supabase` pattern (it's intentional and established)
- No changes to production Supabase keys (local key is fine)
- No changes to sync logic or data flow
- No UI visual changes
- No new tests required (existing tests should continue passing)

---

### Compatibility Plan

- **Backward compatibility**: N/A (internal code quality fixes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit if issues arise

---

### Ownership

- **dispatch-explorer**: Verify CodeRabbit claims against actual codebase patterns (PATCHSET 1)
- **feature-owner**: Implement valid fixes (PATCHSET 2)
- **integrator**: Build verification, lint, tests (PATCHSET 2)

---

### Context7 Attestation [MANDATORY]

> **Enforcement**: Integrator BLOCKS DONE if required reports are missing or CONTEXT7 CONSULTED: NO

#### Required Libraries (filled by planner or feature-owner)

| Library | Context7 ID | Why Needed |
|---------|-------------|------------|
| N/A | N/A | Pure refactoring - no new framework patterns |

**N/A is valid** for this contract: pure refactors with no new framework/library usage.

---

#### Agent Reports

Each agent fills their section below. **Integrator verifies these are complete before DONE.**

##### feature-owner Report (MUST FILL)

**CONTEXT7 CONSULTED**: N/A

_N/A valid for pure refactors with zero framework code._

**Fixes Applied**:
1. `HistoryEntryRow.swift:107-108` - Added `defer { isRestoring = false }` to ensure restore button state resets even if action throws
2. `RecentlyDeletedView.swift:130` - Kept underscore parameter `_: Error` (already correct pattern for unused but available parameter)
3. `AuditEntry.swift:106-295` - Added deterministic preview data: fixed reference date (`previewReferenceDate`) and fixed UUIDs (`PreviewID` enum) for all mock entries
4. `PropertyDetailView.swift:255-263` - Cached DateFormatter as `static let dateFormatter`

**Files Modified**:
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Features/History/HistoryEntryRow.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Features/History/RecentlyDeletedView.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Foundation/Audit/AuditEntry.swift`
- `/Users/noahdeskin/conductor/workspaces/dispatch/salvador/Dispatch/Features/Properties/Views/Screens/PropertyDetailView.swift`

##### ui-polish Report (FILL IF CODE CHANGES)

**CODE CHANGES MADE**: NO

_Not assigned - no UI polish needed._

##### swift-debugger Report (FILL IF INVOKED)

**DEBUGGING PERFORMED**: NO

_Not invoked._

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

_UI Review Required: NO - jobs-critic not required for non-visual code fixes._

---

### Specific Fix Details

#### Fix 1: HistoryEntryRow restore error handling

**Location**: `Dispatch/Features/History/HistoryEntryRow.swift:104-121`

**Current code issue**: If `action()` throws, `isRestoring` remains `true` and button stays disabled forever.

**Fix**: Ensure `isRestoring = false` is called in both success and error paths (use defer or explicit try/catch).

#### Fix 2: RecentlyDeletedView error state

**Location**: `Dispatch/Features/History/RecentlyDeletedView.swift:130`

**Current code**: `private func errorState(_: Error) -> some View` - parameter unused

**Fix**: Either use the error parameter to show a more specific message, or keep the underscore but ensure the generic message is sufficient. Current "Failed to load" with Retry is adequate UX - can optionally add error.localizedDescription in DEBUG builds only.

#### Fix 3: AuditEntry preview mocks determinism

**Location**: `Dispatch/Foundation/Audit/AuditEntry.swift:107-227`

**Current code**: Uses `Date()` and `Date().addingTimeInterval(-X)` which varies each preview render.

**Fix**: Use a fixed reference date (e.g., `Date(timeIntervalSinceReferenceDate: 0)` or a specific date) for preview mocks.

#### Fix 4: PropertyListingRow DateFormatter caching

**Location**: `Dispatch/Features/Properties/Views/Screens/PropertyDetailView.swift:255-259`

**Current code**: Creates new DateFormatter on each `formatDate` call.

**Fix**: Make formatter a static property.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- Context7 Attestation: N/A is valid for pure refactors
