## Interface Lock

**Feature**: Search Code Review Fixes
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
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Notes**: These are code quality fixes from code review, not feature changes. No UI changes, no schema changes, no new navigation flows.

### Patchset Plan

Based on checked indicators (none checked - simple refactor):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: `SearchViewModel.error: SearchError?` (error state)
- Migration required: N

### Acceptance Criteria (3 max)

1. All 7 code review issues addressed and tests pass
2. No duplicate binding bridge code (extracted to shared extension)
3. Task navigation uses O(1) dictionary lookup instead of O(n) linear search

### Non-goals (prevents scope creep)

- No changes to search UI or UX
- No new search features
- No changes to search ranking algorithm
- No changes to SearchEnvironment architecture beyond current fix (complete env injection deferred)

### Compatibility Plan

- **Backward compatibility**: N/A (internal refactors only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits on branch

---

### Ownership

- **feature-owner**: Address all 7 review issues + minor suggestions
- **data-integrity**: Not needed

---

### Issues to Address

#### Issue 1: Test Type Mismatch (SearchIndexServiceTests.swift:82)
**Problem**: `InitialSearchData.tasks` expects `[SearchableTask]`, but tests pass `TaskItem` directly.
**Solution**: Create test helper to convert `TaskItem` to `SearchableTask`.
**Files**: `DispatchTests/Features/Search/SearchIndexServiceTests.swift`

#### Issue 2: Fallback Creates Disconnected ViewModel (ContentView.swift:152, iPhoneContentView.swift:42)
**Problem**: `searchViewModel ?? SearchViewModel()` creates fresh VM that won't share warmed `SearchIndexService`.
**Solution**: Make `searchViewModel` non-optional or pass shared `SearchEnvironment`.
**Files**: `Dispatch/App/ContentView.swift`, `Dispatch/App/Platform/iPhoneContentView.swift`

#### Issue 3: Duplicate Binding Bridge Pattern (SearchOverlay.swift:143-152, NavigationPopover.swift:91-102)
**Problem**: Identical `searchTextBinding` code duplicated in both files.
**Solution**: Extract to shared extension on `SearchViewModel` or create reusable binding helper.
**Files**:
- `Dispatch/Features/Search/Views/Components/SearchOverlay.swift`
- `Dispatch/Foundation/Platform/macOS/NavigationPopover.swift`
- New: Extension file or helper

#### Issue 4: O(n) Lookup for Task Navigation (ContentView.swift:316-318)
**Problem**: `activeTasks.first(where: { $0.id == doc.id })` is O(n) on every navigation.
**Solution**: Pre-build `[UUID: TaskItem]` dictionary for O(1) lookup.
**Files**: `Dispatch/App/ContentView.swift`

#### Issue 5: No Error Handling in warmStart (SearchViewModel.swift:113)
**Problem**: If `warmStart` fails, no error state or retry mechanism.
**Solution**: Add `error: SearchError?` state to `SearchViewModel` and error handling.
**Files**: `Dispatch/Features/Search/ViewModels/SearchViewModel.swift`

#### Issue 6: Split Actor Isolation Documentation (SearchDoc.swift:79-115)
**Problem**: UI properties on `SearchDocType` are `@MainActor` isolated, pattern needs documentation.
**Solution**: Add documentation explaining the split isolation pattern or move to helper struct.
**Files**: `Dispatch/Features/Search/Models/SearchDoc.swift`

#### Issue 7: Missing ViewModel Tests
**Problem**: No tests for debouncing and cancellation logic in `SearchViewModel`.
**Solution**: Add tests for debounce timing, cancellation on new query, and empty query handling.
**Files**: New: `DispatchTests/Features/Search/SearchViewModelTests.swift`

#### Minor: Extract Magic Number
**Problem**: 200ms debounce hardcoded in `SearchViewModel`.
**Solution**: Extract to named constant.
**Files**: `Dispatch/Features/Search/ViewModels/SearchViewModel.swift`

#### Minor: SearchEnvironment Unused (Deferred)
**Note**: SearchEnvironment exists but isn't fully utilized. Complete environment injection pattern deferred - out of scope for this PR.

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A - Pure refactor with no new framework patterns

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: None

| Query | Pattern Used |
|-------|--------------|
| N/A | Pure refactor - existing patterns reused |

**N/A**: This is a pure refactor with no new framework/library patterns. All changes use existing patterns already in the codebase:
- Test helper extension pattern (asSearchable) - already existed
- Binding helper pattern (searchTextBinding) - already existed
- Dictionary lookup pattern (taskLookup) - already existed
- Error state pattern (SearchError) - already existed
- Actor isolation documentation - already existed

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

**Notes**: UI Review Required is NO - these are internal code quality fixes with no customer-facing UI changes.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
