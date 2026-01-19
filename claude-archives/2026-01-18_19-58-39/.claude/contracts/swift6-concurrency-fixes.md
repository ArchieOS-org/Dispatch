## Interface Lock

**Feature**: Swift 6 Concurrency Compiler Error Fixes
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
- [x] **Unfamiliar area** (adds dispatch-explorer) - Swift 6 actor isolation patterns

### Patchset Plan

Based on checked indicators (no schema, no UI, unfamiliar Swift 6 patterns):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles (errors fixed) | feature-owner |
| 2 | Tests pass, all platforms build | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: DTOs need Sendable conformance (TaskDTO, ActivityDTO, ListingDTO, UserDTO, NoteDTO already have it)
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. All 6 files compile without Swift 6 concurrency errors or warnings
2. Build succeeds on iOS Simulator, iPad Simulator, and macOS
3. Existing tests continue to pass

### Non-goals (prevents scope creep)

- No refactoring beyond what's needed to fix the specific compiler errors
- No changes to business logic or sync behavior
- No new tests (existing test coverage sufficient)

### Compatibility Plan

- **Backward compatibility**: N/A (internal implementation changes only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit if issues discovered

---

### Files to Fix

#### 1. ListingGeneratorState.swift (lines 70, 251)

**Error**: Call to main actor-isolated initializer 'init(simulatedDelay:)' in a synchronous nonisolated context

**Analysis**: `MockAIService` has an initializer that is NOT @MainActor isolated, but `ListingGeneratorState` IS @MainActor isolated. The default parameter `aiService: AIServiceProtocol = MockAIService()` is evaluated in a nonisolated context.

**Fix Options**:
- Option A: Make `MockAIService` @MainActor isolated (but it's Sendable, so this may cause issues)
- Option B: Remove the default parameter and require explicit injection
- Option C: Make `MockAIService.init` nonisolated (preferred - the init doesn't access MainActor state)

**Recommended Fix**: Make `MockAIService.init` explicitly `nonisolated` since it only stores a value type (`Duration`) which is safe.

#### 2. AuthManager.swift (line 152)

**Error**: Switch must be exhaustive

**Analysis**: The `AuthChangeEvent` enum has gained new cases since the code was written. The `@unknown default` case exists but a specific case may be missing.

**Fix**: Review current `AuthChangeEvent` cases from Supabase Auth SDK and add any missing cases, or ensure `@unknown default` handles them gracefully.

#### 3. ChannelLifecycleManager.swift

**Multiple Issues**:

a) **Lines 112 (and similar)**: Missing explicit `self` in closures
   - Swift 6 requires explicit `self` capture in escaping closures
   - **Fix**: Add explicit `self.` prefix where needed

b) **Lines 124, 132, 155, 163, 186, 194, 217, 225, 248, 256**: Main actor-isolated Decodable conformance
   - The `handleDTO` method is called with DTOs that conform to `Decodable`
   - `handleDTO` is a `@MainActor` method calling `decodeRecord(as:)` which synthesizes `Decodable` conformance
   - The DTOs (TaskDTO, ActivityDTO, etc.) are already `Sendable`
   - **Fix**: The issue is that `handleDTO` is private and in a @MainActor class, but decoding happens in a non-isolated context. Make `handleDTO` nonisolated and only the callback is @MainActor isolated (which it already is).

c) **Lines 358, 366**: Unnecessary `await` expressions
   - **Fix**: Remove unnecessary `await` keywords

#### 4. CircuitBreaker.swift (lines 78-80)

**Error**: MainActor-isolated static properties accessed from nonisolated context

**Analysis**: `CircuitBreakerPolicy` static properties (`failureThreshold`, `initialCooldown`, `maxCooldown`) are accessed in `CircuitBreaker.init()` default parameters. Static properties in an enum are not isolated, but accessing them from a @MainActor init's default parameters creates an isolation mismatch.

**Fix Options**:
- Option A: Make `CircuitBreakerPolicy` properties `nonisolated` (they're just constants, safe)
- Option B: Move constants outside the enum
- Option C: Use literal values in init default parameters

**Recommended Fix**: The properties are pure constants (`Int`, `TimeInterval`), so they should be marked as `nonisolated(unsafe)` or the enum should use `static let` without any actor isolation concerns. Since they're computed values (they're not, they're `let`), just ensure they're accessed correctly. Actually, examining the code, these ARE already `static let` constants. The issue is Swift 6's stricter inference. Add `nonisolated(unsafe)` or restructure.

#### 5. RetryCoordinator.swift (line 180)

**Error**: MainActor-isolated static property 'autoRecoveryCooldown' accessed from nonisolated context

**Analysis**: Same pattern as CircuitBreaker - `RetryPolicy.autoRecoveryCooldown` is accessed in a default parameter.

**Fix**: Same approach as CircuitBreaker - ensure static constants are accessible from nonisolated contexts.

#### 6. SyncManager.swift (lines 119, 121)

**Warning**: Redundant 'internal(set)' modifiers

**Analysis**: The properties are declared with `internal(set)` but this is redundant when the property is already `internal` by default.

**Fix**: Remove redundant `internal(set)` modifiers.

---

### Context7 Queries (Required)

**Must query before implementing**:
1. Swift 6 actor isolation for static properties in enums
2. Swift 6 nonisolated initializers pattern
3. Swift 6 explicit self in closures requirements
4. Swift concurrency Decodable conformance with MainActor

---

### Ownership

- **feature-owner**: Fix all 6 files per analysis above
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Swift 6 nonisolated static properties actor isolation default parameters MainActor
CONTEXT7_TAKEAWAYS:
- Use `nonisolated(unsafe)` for static vars that need bypass, but unnecessary for `static let` with Sendable types
- For `static let` constants of Sendable types (Int, TimeInterval), they're already safe
- Static properties in enums accessed from @MainActor init defaults need literal values or restructuring
- Swift 6 requires explicit `self` in escaping closures within @MainActor.run blocks
CONTEXT7_APPLIED:
- Literal values in init defaults -> CircuitBreaker.swift:77-80, RetryCoordinator.swift:180

CONTEXT7_QUERY: Supabase AuthChangeEvent enum cases
CONTEXT7_TAKEAWAYS:
- AuthChangeEvent has cases: initialSession, signedIn, signedOut, tokenRefreshed, userUpdated, passwordRecovery, userDeleted, mfaChallengeVerified
- Switch statements on AuthChangeEvent must handle all cases or use @unknown default
CONTEXT7_APPLIED:
- Added .userDeleted case -> AuthManager.swift:198-201

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift), Supabase Swift (/supabase/supabase-swift)

| Query | Pattern Used |
|-------|--------------|
| Swift 6 nonisolated static properties | Literal values in @MainActor init defaults |
| Swift 6 explicit self in closures | Added self. prefix in @MainActor.run closure |
| Swift 6 nonisolated init pattern | Added `nonisolated` to MockAIService.init |
| Supabase AuthChangeEvent cases | Added missing .userDeleted case handler |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
