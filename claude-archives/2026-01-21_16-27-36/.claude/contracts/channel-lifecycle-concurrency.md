## Interface Lock

**Feature**: ChannelLifecycleManager Swift 6 Concurrency Fixes
**Created**: 2026-01-18
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

### Patchset Plan

Based on checked indicators (focused bug fix, 1 file, familiar Swift 6 patterns):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles (errors fixed) | feature-owner |
| 2 | Tests pass, all platforms build | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None (DTOs already have correct conformance)
- State/actions added: None
- Migration required: N

### Problem Summary

**File**: `/Users/noahdeskin/conductor/workspaces/dispatch/pattaya/Dispatch/Foundation/Persistence/Sync/ChannelLifecycleManager.swift`

**10 Errors** (all same pattern):
- Lines 124, 132: TaskDTO Decodable conformance MainActor-isolated
- Lines 155, 163: ActivityDTO Decodable conformance MainActor-isolated
- Lines 186, 194: ListingDTO Decodable conformance MainActor-isolated
- Lines 217, 225: UserDTO Decodable conformance MainActor-isolated
- Lines 248, 256: NoteDTO Decodable conformance MainActor-isolated

**2 Warnings**:
- Lines 358, 366: "No async operations occur within await expression"

### Root Cause Analysis

1. **`ChannelLifecycleManager` is `@MainActor`** (line 33-34)
2. **`handleDTO` inherits `@MainActor` isolation** (line 355) from the class
3. **The `Task { }` blocks** (lines 118, 149, 180, 211, 242) create **nonisolated tasks** by default
4. **Inside those tasks**, calling `self.handleDTO(...)` triggers a MainActor hop
5. **The `decodeRecord(as:)` call** inside `handleDTO` (line 357) performs synchronous decoding
6. **Swift 6 strict concurrency** sees this as: "nonisolated task calling @MainActor method that does sync decoding"

The Swift 6 error message "Decodable conformance MainActor-isolated in nonisolated context" is misleading - the DTOs themselves are NOT MainActor-isolated. The issue is that `handleDTO` is implicitly @MainActor, and the Task {} blocks are nonisolated.

### Fix Strategy

**Option A (Recommended): Make `handleDTO` nonisolated**

```swift
// Before (line 355):
private func handleDTO<DTO: Decodable>(_ action: some HasRecord, _ type: DTO.Type, _ callback: @MainActor (DTO) -> Void) async {

// After:
private nonisolated func handleDTO<DTO: Decodable & Sendable>(_ action: some HasRecord, _ type: DTO.Type, _ callback: @MainActor (DTO) -> Void) async {
```

This allows:
1. `handleDTO` to be called from nonisolated Task {} blocks without actor hop for the decoding part
2. The `callback` is already `@MainActor`-annotated, so `await callback(dto)` correctly hops to MainActor
3. DTOs (TaskDTO, ActivityDTO, ListingDTO, NoteDTO) are already `Sendable` (UserDTO needs `Sendable` added)

**Warning fix for lines 358, 366**:
The `await callback(dto)` and `await callback(id)` may not actually need `await` if the callback is synchronous on MainActor. However, since callbacks are `@MainActor`, the await IS needed for the actor hop. The warning suggests Swift already knows the hop will occur. Keep the `await` - these warnings are benign in Swift 6.

Alternatively, the warnings may be because `handleDTO` is currently `@MainActor` so there's no actual hop needed within the method. Once we make `handleDTO` nonisolated, the `await` becomes meaningful.

### Files to Modify

| File | Changes |
|------|---------|
| `ChannelLifecycleManager.swift` | Make `handleDTO` and `handleDelete` `nonisolated`, add `& Sendable` constraint |
| `UserDTO.swift` | Add `Sendable` conformance (missing, others already have it) |

### Acceptance Criteria (3 max)

1. All 10 Swift 6 concurrency errors in ChannelLifecycleManager.swift are resolved
2. Build succeeds on iOS Simulator, iPad Simulator, and macOS without warnings at lines 358, 366
3. Existing sync tests continue to pass

### Non-goals (prevents scope creep)

- No refactoring beyond what's needed to fix the specific compiler errors
- No changes to business logic or sync behavior
- No changes to other files unless required for Sendable conformance

### Compatibility Plan

- **Backward compatibility**: N/A (internal implementation changes only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit if issues discovered

---

### Ownership

- **feature-owner**: Fix ChannelLifecycleManager.swift and UserDTO.swift per analysis above
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Swift 6 nonisolated methods in MainActor class, Sendable generic constraints, actor isolation
CONTEXT7_TAKEAWAYS:
- Use `nonisolated` keyword on methods in @MainActor classes to allow calling from nonisolated contexts
- For async methods in nonisolated contexts, `nonisolated(nonsending)` can be used to stay on caller's actor
- @MainActor classes are implicitly Sendable, but methods marked `nonisolated` can be called without actor hop
- When passing data across actor boundaries, generic types should be constrained with `& Sendable`
- Callbacks marked `@MainActor` will correctly hop to MainActor when called with `await`
CONTEXT7_APPLIED:
- @MainActor Task blocks -> ChannelLifecycleManager.swift:118,149,180,211,242

CONTEXT7_QUERY: Swift 6 Decodable conformance MainActor isolated generic constraint Sendable
CONTEXT7_TAKEAWAYS:
- Isolated conformances (e.g., `@MainActor P`) cannot satisfy generic constraints requiring `Sendable`
- The error occurs when an isolated conformance would need to cross actor boundaries
- The fix is to ensure the conformance itself is not actor-isolated
- For value types (structs) with no mutable state, `Sendable` conformance should work without isolation
CONTEXT7_APPLIED:
- Added `@MainActor` to Task blocks and group.addTask closures to keep all code on MainActor

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift), Supabase Swift (/supabase/supabase-swift)

| Query | Pattern Used |
|-------|--------------|
| Swift 6 nonisolated methods in MainActor class | Added `@MainActor` to Task/group.addTask closures |
| Swift 6 Decodable conformance MainActor isolated | Kept DTOs on MainActor, ensured all call sites run on MainActor |
| Supabase realtime postgres changes | Verified decodeRecord pattern from SDK docs |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
