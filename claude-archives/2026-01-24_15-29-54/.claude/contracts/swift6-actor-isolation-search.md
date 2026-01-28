## Interface Lock

**Feature**: Swift 6 Actor Isolation Fix for Instant Search
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
- [x] **Unfamiliar area** (adds dispatch-explorer) - Swift 6 actor isolation with SwiftData

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles with zero Swift 6 errors | feature-owner |
| 2 | Tests pass, all 25 errors resolved | feature-owner, integrator |

---

### Problem Statement

The `SearchIndexService` actor cannot access `InitialSearchData` properties or `SearchDoc.from()` methods because they are MainActor-isolated due to SwiftData `@Model` types.

**Error Count**: 25 Swift 6 actor isolation errors

**Root Cause**: SwiftData `@Model` types (`User`, `Listing`, `Property`, `TaskItem`) are implicitly MainActor-isolated. When:
1. `InitialSearchData` holds arrays of these `@Model` types, accessing its properties requires MainActor
2. `SearchDoc.from(realtor:)` etc. access `@Model` properties, making them MainActor-isolated
3. `SearchDoc.normalize()` and `tokenize()` become inferred MainActor-isolated through usage
4. `SearchDocType.<` operator becomes MainActor-isolated

### Contract

- New/changed model fields: None
- DTO/API changes: New `SearchableData` struct (Sendable DTO for cross-actor transfer)
- State/actions added: None
- Migration required: N

### Solution: Extract-on-MainActor Pattern (Option C)

Per Swift 6 actor isolation rules, `@Model` data cannot cross actor boundaries directly. The correct pattern is:

1. **Create Sendable DTOs** that mirror searchable fields from each `@Model` type
2. **Extract data ON MainActor** before crossing to background actor
3. **Pass Sendable DTOs** to `SearchIndexService.warmStart()`
4. **Keep `SearchDoc` utilities nonisolated** since they only work with Sendable data

This follows the Swift concurrency principle: data crossing actor boundaries must be `Sendable`.

### Files to Modify

| File | Change |
|------|--------|
| `SearchDoc.swift` | Add `SearchableData` protocol and conforming structs; make `from()` methods accept DTOs |
| `InitialSearchData.swift` | Change to hold DTO arrays instead of `@Model` arrays |
| `SearchIndexService.swift` | No changes needed (receives Sendable data) |
| `ContentView.swift` | Extract DTO data from `@Model` arrays before calling `warmStart()` |

### Acceptance Criteria (3 max)

1. Zero Swift 6 actor isolation errors when building for iOS and macOS
2. Search functionality works identically (same results, same ranking)
3. Background indexing still runs off MainActor (no performance regression)

### Non-goals (prevents scope creep)

- No changes to search ranking algorithm
- No changes to SearchIndexService internal implementation
- No UI changes
- No new features

### Compatibility Plan

- **Backward compatibility**: N/A (internal refactor only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert to previous commit if search breaks

---

### Ownership

- **feature-owner**: Implement Sendable DTO pattern across all 4 files
- **data-integrity**: Not needed (no schema changes)

---

### Technical Design

#### New Types (in SearchDoc.swift)

```swift
// MARK: - Sendable DTOs for Actor Boundary Crossing

/// Minimal data extracted from @Model types for search indexing.
/// These are Sendable and can safely cross actor boundaries.

struct SearchableRealtor: Sendable {
  let id: UUID
  let name: String
  let email: String
  let updatedAt: Date
}

struct SearchableListing: Sendable {
  let id: UUID
  let address: String
  let city: String
  let postalCode: String
  let statusRawValue: String
  let statusDisplayName: String
  let updatedAt: Date
}

struct SearchableProperty: Sendable {
  let id: UUID
  let displayAddress: String
  let city: String
  let postalCode: String
  let propertyTypeDisplayName: String
  let updatedAt: Date
}

struct SearchableTask: Sendable {
  let id: UUID
  let title: String
  let taskDescription: String
  let statusRawValue: String
  let statusDisplayName: String
  let updatedAt: Date
}
```

#### Updated InitialSearchData

```swift
struct InitialSearchData: Sendable {
  let realtors: [SearchableRealtor]
  let listings: [SearchableListing]
  let properties: [SearchableProperty]
  let tasks: [SearchableTask]
}
```

#### Updated SearchDoc Factory Methods

```swift
static func from(realtor: SearchableRealtor) -> SearchDoc { ... }
static func from(listing: SearchableListing) -> SearchDoc { ... }
// etc.
```

#### ContentView Extraction (on MainActor)

```swift
@MainActor
private func warmStartSearchIndex() async {
  // Extract Sendable data from @Model arrays ON MainActor
  let realtorDTOs = activeRealtors.map {
    SearchableRealtor(id: $0.id, name: $0.name, email: $0.email, updatedAt: $0.updatedAt)
  }
  // ... same for other types

  let data = InitialSearchData(
    realtors: realtorDTOs,
    listings: listingDTOs,
    properties: propertyDTOs,
    tasks: taskDTOs
  )

  // Now safe to pass to background actor
  await viewModel.warmStart(with: data)
}
```

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- Swift: "Swift 6 actor isolation crossing actor boundaries @MainActor isolated data Sendable transfer SwiftData @Model types nonisolated async"
  - Pattern: Use Sendable DTOs to transfer data across actor boundaries; extract data on source actor before crossing
  - `nonisolated(nonsending)` is for methods that should run on caller's actor, not for data transfer
  - Data crossing actor boundaries MUST be Sendable

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift)

CONTEXT7_QUERY: Swift 6 actor isolation Sendable data crossing actor boundaries how to transfer data between actors
CONTEXT7_TAKEAWAYS:
- Data crossing actor boundaries MUST be Sendable
- Use `nonisolated(nonsending)` for methods that should run on caller's actor
- Non-Sendable class instances shared between actors cause data races
- Simple structs with Sendable properties automatically conform to Sendable
- Extract data to Sendable DTOs before crossing actor boundaries
CONTEXT7_APPLIED:
- Sendable DTOs pattern -> SearchDoc.swift (SearchableRealtor, SearchableListing, SearchableProperty, SearchableTask)

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

This is a backend refactor with no UI changes. UI Review Required: NO.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
