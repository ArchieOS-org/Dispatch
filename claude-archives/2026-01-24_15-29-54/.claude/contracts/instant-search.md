## Interface Lock

**Feature**: Instant Search with Background Indexing
**Created**: 2026-01-22
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None (read-only indexing of existing models)
- DTO/API changes: None
- State/actions added:
  - `SearchIndexService` (new actor)
  - `SearchDoc` (new struct)
  - `SearchIndexChange` (new enum for incremental updates)
  - `SearchViewModel` (new ObservableObject for debounced queries)
- Migration required: N

### Acceptance Criteria (3 max)

1. **Zero keyboard lag**: Opening search + focusing TextField must NEVER cause keyboard lag. No O(N) indexing work on main thread during search UI open, focus, or typing.
2. **Correct search scope**: Search indexes ONLY Realtors (User with userType=.realtor), Listings, Properties, Tasks. Activities are NOT indexed, searchable, or ranked.
3. **Ranking correctness**: Results ranked by: phrase match > exact token coverage > starts-with boost > type priority (realtor > listing > property > task) > recency > stable tie-breaker.

### Non-goals (prevents scope creep)

- No fuzzy matching or typo tolerance
- No search history or recent searches persistence
- No search analytics or telemetry
- No Activities in search (explicitly excluded)
- No changes to existing SearchOverlay layout or styling
- No changes to Quick Jump navigation items

### Compatibility Plan

- **Backward compatibility**: N/A (new feature, no existing API)
- **Default when missing**: N/A
- **Rollback strategy**: Feature can be disabled by reverting SearchResultsList to use existing filtering logic instead of SearchIndexService

---

### Technical Specification

#### 1. SearchIndexService (Actor)

```swift
actor SearchIndexService {
  // Data structures
  private var idToDoc: [UUID: SearchDoc] = [:]
  private var idToTokens: [UUID: [String]] = [:]
  private var tokenToIDs: [String: Set<UUID>] = [:]

  // Readiness state
  enum Readiness { case idle, building, ready, failed }
  private(set) var readiness: Readiness = .idle

  // Public API
  func warmStart(realtors: [User], listings: [Listing], properties: [Property], tasks: [TaskItem]) async
  func apply(change: SearchIndexChange) async
  func search(query: String, limit: Int) async -> [SearchDoc]
}
```

#### 2. SearchDoc (Struct)

```swift
struct SearchDoc: Identifiable, Sendable {
  let id: UUID
  let type: SearchDocType  // realtor | listing | property | task
  let updatedAt: Date
  let primaryText: String
  let secondaryText: String
  let searchKey: String    // normalized, concatenated searchable text
}

enum SearchDocType: Int, Sendable {
  case realtor = 0
  case listing = 1
  case property = 2
  case task = 3
}
```

#### 3. Normalization + Tokenization

- `normalize()`: lowercase, remove diacritics, collapse whitespace, keep alphanumerics
- `tokenize()`: split on non-alphanumerics, drop tokens < 2 chars (except numbers), dedupe

#### 4. Warm Build Timing

- Start `warmStart()` AFTER first frame renders
- Use `Task(priority: .utility)` for background work
- Only publish single "ready" signal at end (no intermediate state updates)

#### 5. Incremental Updates

Hook into write path for create/update/delete of 4 entity types:
- `SearchIndexChange.created(SearchDoc)`
- `SearchIndexChange.updated(SearchDoc)`
- `SearchIndexChange.deleted(UUID)`

#### 6. Search Algorithm

1. Normalize query, tokenize
2. If empty tokens: return recent docs with type priority
3. Intersect candidate sets from tokenToIDs
4. If intersection empty + query >= 3 chars: limited fallback on 500 recent docs
5. Rank candidates, return top limit

#### 7. Ranking Rules (strict order)

1. Phrase match (searchKey contains full normalized query)
2. Exact token coverage (all query tokens match)
3. Starts-with boost (primaryText tokens start with query token)
4. Type priority: realtor(0) > listing(1) > property(2) > task(3)
5. Recency (updatedAt desc)
6. Stable tie-breaker (primaryText asc)

#### 8. SearchViewModel

```swift
@MainActor
final class SearchViewModel: ObservableObject {
  @Published var query: String = ""
  @Published var results: [SearchDoc] = []
  @Published var isSearching: Bool = false

  // Debounce 150-250ms
  // Cancel previous search task on new query
  // Publish results via @Published
}
```

#### 9. UI Integration Points

Files to modify:
- `SearchResultsList.swift` - Use SearchViewModel instead of direct filtering
- `SearchOverlay.swift` - Inject SearchViewModel, trigger warmStart timing
- `ContentView.swift` or app entry - Initialize SearchIndexService, warm after first frame

#### 10. Entity Field Mapping

| Entity | primaryText | secondaryText |
|--------|-------------|---------------|
| Realtor (User) | name | email |
| Listing | address | city + status |
| Property | displayAddress | city + propertyType |
| TaskItem | title | taskDescription |

---

### Ownership

- **feature-owner**: End-to-end implementation of SearchIndexService actor, SearchDoc, SearchViewModel, integration with existing search UI, incremental update hooks
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Swift actor definition isolation nonisolated async method patterns
CONTEXT7_TAKEAWAYS:
- Actors provide thread-safe isolated state management
- nonisolated(nonsending) allows running on caller's actor context
- async methods within actors execute on actor's executor
- Use Task.yield() to prevent blocking during long operations
CONTEXT7_APPLIED:
- Actor isolation for SearchIndexService -> SearchIndexService.swift

CONTEXT7_QUERY: String Unicode normalization folding diacriticInsensitive caseInsensitive
CONTEXT7_TAKEAWAYS:
- Use String.folding(options:locale:) for normalization
- Options: .diacriticInsensitive, .caseInsensitive for search
- Case folding does not preserve normalization formats
- Localized operations should be case-insensitive by default
CONTEXT7_APPLIED:
- String normalization via folding() -> SearchDoc.swift:normalize()

CONTEXT7_QUERY: ObservableObject StateObject EnvironmentObject async Task debounce state management best practices
CONTEXT7_TAKEAWAYS:
- Use @StateObject for creating and owning ObservableObject instances in parent views
- Use @ObservedObject when passing an ObservableObject as a parameter to child views
- Use @EnvironmentObject for shared data access across view hierarchy
- @Published properties trigger automatic view updates
- Use .task {} modifier for async work that runs before view appears
CONTEXT7_APPLIED:
- @StateObject for searchEnvironment in ContentView -> ContentView.swift
- @ObservedObject for searchViewModel in InstantSearchResultsList -> InstantSearchResultsList.swift

CONTEXT7_QUERY: task modifier async await onAppear background loading
CONTEXT7_TAKEAWAYS:
- Use .task(priority:) modifier for async operations before view appears
- Task is automatically cancelled when view disappears
- Can specify priority level (e.g., .userInitiated, .utility)
- Use task(id:) to re-trigger when value changes
CONTEXT7_APPLIED:
- .task {} for warm start in ContentView -> ContentView.swift:warmStartSearchIndex()

---

### Context7 Attestation (written by feature-owner at PATCHSET 1, updated at PATCHSET 2)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Swift (/swiftlang/swift), SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Swift actor isolation patterns | Actor-based SearchIndexService with private state isolation |
| String Unicode normalization folding | String.folding(options: [.diacriticInsensitive, .caseInsensitive], locale:) |
| ObservableObject StateObject EnvironmentObject | @StateObject for SearchEnvironment, @ObservedObject for SearchViewModel in child views |
| task modifier async await | .task {} for deferred warmStart after first frame renders |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline > primary > secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Files Reviewed:**
- `InstantSearchResultsList.swift` - new results list view
- `SearchOverlay.swift` - search overlay integration
- `SearchDoc.swift` - icons and colors for result types
- `SearchResultRow.swift` - individual result row component
- `SearchViewModel.swift` - debounced search state management

**Execution Findings:**
- All DS tokens used correctly (spacing, typography, colors, icons)
- Touch targets at 56pt (exceeds 44pt minimum)
- All states handled: empty (Quick Jump), searching (ProgressView), no results (helpful message), results (grouped list)
- Accessibility complete: combined accessibilityElement, labels, hints, @ScaledMetric for Dynamic Type
- Section colors properly mapped via `DS.Colors.Section.*` for realtor/listing/property/task
- Divider insets align with content hierarchy
- 200ms debounce provides responsive feel with loading indicator

**No issues found. Clean implementation following platform conventions.**

---

### Implementation Notes

**Context7 Recommended For:**
- Swift actors and structured concurrency patterns (`/swiftlang/swift`)
- SwiftUI state management and @Published patterns (`/websites/developer_apple_swiftui`)
- String normalization and Unicode handling patterns

**Key Performance Constraints:**
- ALL indexing work MUST happen off main thread (actor isolation)
- warmStart MUST be deferred until after first frame
- Search queries should complete in <50ms for typical datasets
- Debounce prevents excessive recomputation during typing

**Testing Strategy:**
- Unit tests for normalization/tokenization
- Unit tests for ranking algorithm correctness
- Unit tests for incremental update correctness
- Performance tests for index build time
- UI tests NOT required (existing search UI unchanged)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
