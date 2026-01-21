## Interface Lock

**Feature**: Swift 6 Concurrency Regression Tests for Sync System
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
- [x] **Unfamiliar area** (adds dispatch-explorer) - Swift 6 compile-time Sendable testing patterns

### Patchset Plan

Based on checked indicators (test-only addition, unfamiliar Swift 6 testing patterns):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles (new test file builds) | feature-owner |
| 2 | All tests pass on iOS Simulator and macOS | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Background

We recently fixed Swift 6 concurrency errors in `ChannelLifecycleManager.swift` where `@MainActor`-isolated code attempted to use `Decodable` conformances in nonisolated `Task` contexts. The fix involved adding `@MainActor` to Task closures to keep all code on the main actor.

The DTOs (TaskDTO, ActivityDTO, ListingDTO, UserDTO, NoteDTO) all have `Sendable` conformance, which is critical for correct Swift 6 concurrency behavior. We need tests to prevent regression.

### Goals

1. **Compile-time Sendable conformance tests** for all sync DTOs
   - TaskDTO, ActivityDTO, ListingDTO, UserDTO, NoteDTO
   - Tests should fail to compile if `Sendable` is removed from any DTO
   - Pattern: Assign DTO to a variable constrained to `Sendable`

2. **ChannelLifecycleManager async context tests**
   - Verify DTOs can be decoded and passed across actor boundaries
   - Exercise the pattern used in realtime handlers
   - Test that Task closures with `@MainActor` annotation work correctly

3. **MainActor isolation verification** (optional, if feasible)
   - Test that Task closures in sync code maintain `@MainActor` isolation
   - May require runtime verification rather than compile-time

### Files to Reference

| File | Purpose |
|------|---------|
| `Dispatch/Foundation/Persistence/Sync/ChannelLifecycleManager.swift` | The fixed file with `@MainActor` Task patterns |
| `Dispatch/Foundation/Networking/Supabase/DTOs/TaskDTO.swift` | Example DTO with `Sendable` |
| `Dispatch/Foundation/Networking/Supabase/DTOs/ActivityDTO.swift` | Example DTO with `Sendable` |
| `Dispatch/Foundation/Networking/Supabase/DTOs/ListingDTO.swift` | Example DTO with `Sendable` |
| `Dispatch/Foundation/Networking/Supabase/DTOs/UserDTO.swift` | Example DTO with `Sendable` |
| `Dispatch/Foundation/Networking/Supabase/DTOs/NoteDTO.swift` | Example DTO with `Sendable` |
| `DispatchTests/DTOTests.swift` | Existing DTO test patterns |
| `DispatchTests/SyncManagerIsolationTests.swift` | Existing isolation test patterns |

### Files to Create

| File | Purpose |
|------|---------|
| `DispatchTests/SendableConformanceTests.swift` | Compile-time Sendable verification |
| `DispatchTests/ChannelLifecycleConcurrencyTests.swift` | Async context tests for ChannelLifecycleManager |

### Test Patterns

#### 1. Sendable Conformance Tests (Compile-Time)

```swift
// This pattern verifies Sendable conformance at compile time.
// If Sendable is removed from TaskDTO, this code will fail to compile.
@Test("TaskDTO conforms to Sendable")
func testTaskDTOSendable() {
  let dto = TaskDTO(/* ... */)

  // This assignment only compiles if TaskDTO: Sendable
  let sendable: any Sendable = dto
  _ = sendable
}

// Alternative: Generic function approach
func verifySendable<T: Sendable>(_ value: T) { }

@Test("All sync DTOs conform to Sendable")
func testAllSyncDTOsSendable() {
  verifySendable(TaskDTO(/* ... */))
  verifySendable(ActivityDTO(/* ... */))
  verifySendable(ListingDTO(/* ... */))
  verifySendable(UserDTO(/* ... */))
  verifySendable(NoteDTO(/* ... */))
}
```

#### 2. Async Context Tests

```swift
@MainActor
@Test("TaskDTO can be decoded and passed across MainActor boundary")
func testTaskDTOAcrossActorBoundary() async {
  // Simulate the pattern from ChannelLifecycleManager:
  // Task { @MainActor in ... handleDTO(...) }

  let dto = TaskDTO(/* ... */)

  // Verify we can use the DTO within a @MainActor Task closure
  let result = await Task { @MainActor in
    // This simulates handleDTO's callback invocation
    return dto.toModel()
  }.value

  #expect(result.id == dto.id)
}
```

#### 3. Task Closure Isolation Test

```swift
@MainActor
@Test("Task closures maintain MainActor isolation")
func testTaskClosureIsolation() async {
  var executedOnMainActor = false

  await Task { @MainActor in
    // This should execute on MainActor
    executedOnMainActor = Thread.isMainThread
  }.value

  #expect(executedOnMainActor == true)
}
```

### Acceptance Criteria (3 max)

1. Tests fail to compile if `Sendable` conformance is removed from any of the 5 sync DTOs
2. Tests verify DTOs can be decoded and used within `@MainActor` Task closures (pattern from ChannelLifecycleManager)
3. All tests pass on iOS Simulator and macOS

### Non-goals (prevents scope creep)

- No changes to production code (DTOs, ChannelLifecycleManager, etc.)
- No testing of realtime subscription logic (too complex to mock)
- No integration tests requiring Supabase connection

### Compatibility Plan

- **Backward compatibility**: N/A (test-only changes)
- **Default when missing**: N/A
- **Rollback strategy**: Delete test files if needed

---

### Ownership

- **feature-owner**: Create test files following existing patterns in DispatchTests/
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Requirements

feature-owner SHOULD query Context7 for:

1. **Swift 6 Sendable testing patterns**
   - Library: `/swiftlang/swift`
   - Query: "Swift 6 Sendable conformance compile-time verification testing"

2. **Swift Testing framework (@Test macro)**
   - Library: `/apple/swift-testing` or resolve via `resolve-library-id`
   - Query: "Swift Testing async test patterns @MainActor"

3. **Actor isolation verification**
   - Library: `/swiftlang/swift`
   - Query: "Swift 6 MainActor isolation Task closure verification"

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Swift 6 Sendable conformance compile-time verification testing patterns
CONTEXT7_TAKEAWAYS:
- Use generic function with `<T: Sendable>` constraint to verify Sendable at compile time
- Assignment to `any Sendable` also provides compile-time verification
- Non-Sendable types captured in concurrent Tasks generate warnings/errors
CONTEXT7_APPLIED:
- Generic verifySendable<T: Sendable> function -> SendableConformanceTests.swift:23

CONTEXT7_QUERY: Swift Testing async test patterns MainActor Test macro
CONTEXT7_TAKEAWAYS:
- Test functions can be marked `async` and annotated with `@MainActor`
- Use `await` for asynchronous interactions in test body
- Pattern: `@Test @MainActor func testName() async { ... }`
CONTEXT7_APPLIED:
- @MainActor async test pattern -> SendableConformanceTests.swift:212, ChannelLifecycleConcurrencyTests.swift:18

CONTEXT7_QUERY: MainActor Task closure isolation verification async
CONTEXT7_TAKEAWAYS:
- `Task { @MainActor in }` ensures closure runs on main actor
- Task closures inherit actor context with @_inheritActorContext (implicit for @MainActor)
- Use Thread.isMainThread to verify MainActor execution at runtime
CONTEXT7_APPLIED:
- Task { @MainActor in } pattern -> ChannelLifecycleConcurrencyTests.swift:25

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: /swiftlang/swift, /websites/developer_apple_testing

| Query | Pattern Used |
|-------|--------------|
| Swift 6 Sendable compile-time verification | Generic `verifySendable<T: Sendable>()` function + `any Sendable` assignment |
| Swift Testing async @MainActor patterns | `@Test @MainActor func test() async { }` |
| MainActor Task closure isolation | `Task { @MainActor in }` with Thread.isMainThread verification |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
