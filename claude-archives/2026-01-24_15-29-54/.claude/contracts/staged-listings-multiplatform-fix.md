## Interface Lock

**Feature**: StagedListingsView Multiplatform Fix (iPad/macOS)
**Created**: 2025-01-21
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

Based on checked indicators (none checked - this is a bug fix with no new UI):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Root Causes Identified

**Issue 1: Missing Stage Parameter Observer**
- **Location**: `Dispatch/Features/Listings/Views/Screens/StagedListingsView.swift:112-117`
- **Problem**: View has `.onChange(of: allListingsRaw)` and `.onChange(of: users)` but NOT `.onChange(of: stage)`
- **Impact**: When switching stages on iPad/macOS, `groupedByOwner` is never recalculated because `stage` is a `let` constant passed at init, and SwiftUI may reuse the view instance
- **Fix**: The `stage` property is a `let` constant, so SwiftUI's view diffing should create a new view when it changes. However, with NavigationSplitView, view identity may be preserved incorrectly. Add `.id(stage)` modifier to force view recreation when stage changes.

**Issue 2: NavigationSplitView View Reuse**
- **Location**: `Dispatch/App/Platform/iPadContentView.swift:45-48`, `Dispatch/App/Platform/MacContentView.swift:43-47`
- **Problem**: NavigationSplitView may preserve view identity in the detail pane, causing `StagedListingsView` to not reinitialize when `stage` changes
- **Impact**: View shows stale data from previous stage selection
- **Fix**: Add `.id()` modifier to detail NavigationStack keyed on `selectedDestination` to force recreation

### Acceptance Criteria (3 max)

1. StagedListingsView shows correct listings when switching between stages on iPad
2. StagedListingsView shows correct listings when switching between stages on macOS
3. Builds pass on iOS, iPadOS, and macOS with no regressions on iPhone

### Non-goals (prevents scope creep)

- No refactoring of StagedListingsView query patterns
- No changes to sidebar selection logic
- No changes to navigation routing architecture
- No new empty/loading/error states (existing ContentUnavailableView is sufficient)

### Compatibility Plan

- **Backward compatibility**: N/A (bug fix only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commit if regressions appear

---

### Ownership

- **feature-owner**: Add `.id()` modifiers to force view identity changes in NavigationSplitView detail panes
- **data-integrity**: Not needed

---

### Files to Modify

1. `Dispatch/App/Platform/iPadContentView.swift` - Add `.id()` to detail NavigationStack
2. `Dispatch/App/Platform/MacContentView.swift` - Add `.id()` to detail NavigationStack

### Implementation Notes

**Primary Fix Strategy**: Add `.id(appState.router.selectedDestination)` to the detail NavigationStack in both platform content views. This forces SwiftUI to recreate the entire navigation stack (including StagedListingsView) when the sidebar selection changes.

**Why this works**: NavigationSplitView tries to preserve view identity for performance. When `selectedDestination` changes from `.stage(.prep)` to `.stage(.active)`, SwiftUI may reuse the existing `StagedListingsView` instance. Since `stage` is a `let` constant, the view body re-executes but with the OLD stage value cached. Adding `.id()` breaks this optimization and forces a fresh view.

**Context7 Recommended Queries**:
- SwiftUI NavigationSplitView view identity and `.id()` modifier behavior
- SwiftUI view identity with NavigationStack in detail column

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: NavigationSplitView detail column view identity .id modifier force recreation
CONTEXT7_TAKEAWAYS:
- `id(_:)` modifier controls view identity and triggers state reinitialization
- When identity changes, SwiftUI reinitializes state object (and recreates the view)
- NavigationSplitView detail pane may preserve view identity across selections
- Use `id()` to force view recreation when input changes
CONTEXT7_APPLIED:
- `.id(appState.router.selectedDestination)` -> iPadContentView.swift:48, MacContentView.swift:47

CONTEXT7_QUERY: onChange modifier SwiftUI view lifecycle state changes best practices
CONTEXT7_TAKEAWAYS:
- `onChange(of:initial:_:)` observes state changes and performs side effects
- Closure receives both old and new values (or just uses `initial: true` for first run)
- Commonly used to synchronize UI state with business logic
CONTEXT7_APPLIED:
- `.onChange(of: stage)` -> StagedListingsView.swift:118

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| NavigationSplitView detail column view identity .id modifier | `.id()` modifier on NavigationStack to force view recreation |
| onChange modifier SwiftUI view lifecycle | `.onChange(of: stage)` for defensive stage change handling |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

This is a bug fix with no customer-facing UI changes. UI Review Required is NO.

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` → integrator MUST reject DONE
