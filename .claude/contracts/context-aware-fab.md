## Interface Lock

**Feature**: Context-Aware FAB Behavior
**Created**: 2026-01-19
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

- New/changed model fields: None (uses existing IDs for context)
- DTO/API changes: None
- State/actions added:
  - Extend `SheetState` enum with new cases for context-aware creation
  - New `FABContext` enum to describe current screen context
  - Possibly new sheet state cases for pre-selected listing workflows
- Migration required: N

### Current State Analysis

**iPhone/iPad (iOS)**:
- `GlobalFloatingButtons.swift` (iPhone): FAB always opens `.quickEntry(type: nil)` - no context awareness
- `iPadContentView.swift` (iPad): FAB overlay always opens `.quickEntry(type: nil)` - no context awareness

**macOS**:
- `BottomToolbar.swift`: Already context-aware via `ToolbarContext` enum
- Different actions for list vs detail views
- `AppState.dispatch(.newItem)` has basic context awareness via `selectedDestination.asTab`

**Key Files**:
| File | Role | Changes Needed |
|------|------|----------------|
| `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/App/State/AppState.swift` | SheetState enum, dispatch commands | Extend SheetState with context cases |
| `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` | iPhone FAB | Add context awareness |
| `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/App/Platform/iPadContentView.swift` | iPad FAB | Add context awareness |
| `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/Foundation/Platform/macOS/BottomToolbar.swift` | macOS toolbar | Align with new context system |
| `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/Features/WorkItems/Views/Sheets/QuickEntrySheet.swift` | Task/Activity creation | Accept pre-selected listing |
| `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/Design/Shared/Components/FloatingActionButton.swift` | FAB component | May need menu support |

### Acceptance Criteria (3 max)

1. FAB shows correct options based on current screen across iOS, iPadOS, and macOS:
   - Workspace: Task, Activity, Listing
   - Stage view / Listing lists: Listing only
   - Listing detail: Task or Activity (listing pre-selected)
   - Realtor tab: Property or Listing (for that realtor)
   - Properties screen: Property
2. When creating Task/Activity from listing detail, that listing is pre-selected in QuickEntrySheet
3. Cross-platform consistency: same context logic produces same options on all platforms

### Non-goals (prevents scope creep)

- No new Property creation sheet (if not exists - just wire FAB to existing or placeholder)
- No changes to the visual appearance of the FAB button itself
- No changes to how sheets look/behave internally (just what gets opened)
- No realtor pre-selection for listings (v2 enhancement)

### Compatibility Plan

- **Backward compatibility**: Existing `.quickEntry(type: nil)` behavior preserved as default
- **Default when missing**: If context cannot be determined, fall back to workspace behavior (Task/Activity/Listing)
- **Rollback strategy**: SheetState changes are additive; old cases still work

---

### Design Approach

#### Option A: Context Environment Value (Recommended)

Pass FAB context via SwiftUI environment:

```swift
enum FABContext: Equatable {
  case workspace
  case stage(ListingStage)
  case listingList
  case listingDetail(listingId: UUID)
  case realtorTab(realtorId: UUID?)
  case properties
}

// Views set their context
.environment(\.fabContext, .listingDetail(listingId: listing.id))

// FAB reads context and determines options
```

**Pros**: Clean separation, testable, platform-agnostic
**Cons**: Need to ensure context is set at right level in view hierarchy

#### Option B: Router-Based Context

Derive context from `AppRouter.selectedDestination` and navigation path:

```swift
// In FAB or its container
var fabContext: FABContext {
  switch appState.router.selectedDestination {
  case .tab(.listings): .listingList
  case .stage(let stage): .stage(stage)
  // etc.
  }
}
```

**Pros**: Uses existing state, no new plumbing
**Cons**: Hard to get detail view context (need to inspect navigation path)

#### Recommendation: Hybrid

- Use router for tab/stage context (already tracked)
- Use environment for detail view context (set by detail views)
- FAB checks environment first, falls back to router

---

### SheetState Extensions

```swift
enum SheetState: Equatable, Identifiable {
  case none
  case quickEntry(type: QuickEntryItemType?, preSelectedListingId: UUID?)  // Extended
  case addListing(forRealtorId: UUID?)  // Extended with optional realtor
  case addRealtor
  case addProperty(forRealtorId: UUID?)  // New case

  // FAB menu for multi-option contexts
  case fabMenu(context: FABContext)  // Shows action sheet/menu
}
```

---

### Platform Implementation Notes

**iPhone** (`GlobalFloatingButtons.swift`):
- Read `FABContext` from environment
- If single action (e.g., listing detail -> Task/Activity only), show action sheet
- If multi-action, show FAB menu sheet

**iPad** (`iPadContentView.swift`):
- Same as iPhone but positioned differently
- May want popover instead of action sheet for multi-option

**macOS** (`BottomToolbar.swift`):
- Already has `ToolbarContext` - align with new `FABContext`
- Use existing `onNew` callback pattern but make it context-aware

---

### Ownership

- **feature-owner**: End-to-end implementation of FABContext, SheetState extensions, and platform FAB updates
- **data-integrity**: Not needed (no schema changes)
- **dispatch-explorer**: Initial exploration to understand navigation context patterns (done in this analysis)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: How to create a custom EnvironmentKey and EnvironmentValues extension for custom environment values
CONTEXT7_TAKEAWAYS:
- Use @Entry macro on property declarations in EnvironmentValues extension (Swift 5.9+)
- Alternative: Create private struct conforming to EnvironmentKey with static defaultValue
- Create View modifier extension for convenient .fabContext() syntax
- Read with @Environment(\.fabContext) property wrapper
- Provide default value that makes sense for fallback behavior
CONTEXT7_APPLIED:
- EnvironmentKey pattern -> FABContext.swift:34-44

CONTEXT7_QUERY: confirmationDialog presenting multiple actions from button tap with isPresented binding
CONTEXT7_TAKEAWAYS:
- Use @State bool to control dialog presentation, set true on button tap
- confirmationDialog(_:isPresented:titleVisibility:actions:) takes title text, binding, and ViewBuilder for actions
- All dialog buttons auto-dismiss after action runs
- Use role: .cancel on a button to replace default dismiss action
- Dialog shows buttons with standard prominence, system reorders by role
CONTEXT7_APPLIED:
- confirmationDialog for multi-option FAB -> GlobalFloatingButtons.swift, iPadContentView.swift

---

### Context7 Attestation (written by feature-owner at PATCHSET 1, updated PATCHSET 2)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| How to create a custom EnvironmentKey and EnvironmentValues extension | Private struct conforming to EnvironmentKey with static defaultValue, computed property in EnvironmentValues extension, View modifier extension |
| confirmationDialog presenting multiple actions from button tap | @State bool for isPresented, ViewBuilder for actions, auto-dismiss on action |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - FABContext enum has exactly 5 cases, no unnecessary complexity. Single-action contexts bypass menu entirely.
- [x] One clear primary action per screen/state - Each context has well-defined primary path. Direct actions for listingList/properties, menus only when multiple options are valid.
- [x] Strong hierarchy - Consistent menu ordering (work items before entities). macOS uses Divider() to separate groups.
- [x] No clutter - FAB remains single button. Context-awareness invisible until tap. confirmationDialog shows options only when needed.
- [x] Native feel - iPhone/iPad use confirmationDialog (action sheet). macOS uses Menu in toolbar. Platform conventions followed precisely.

#### Verdict Notes

**What works well:**
1. FABContext environment value is clean SwiftUI-idiomatic pattern with sensible default (.workspace)
2. Context propagation is correct at all levels (tab roots, AppDestinations, EntityResolvers)
3. AddPropertySheet is Jobs-standard with proper presentation detents, smart defaults, and edge case handling
4. Naming is clear and consistent: "New Task" / "New Activity" / "New Listing" / "New Property"
5. Labels include SF Symbols from DS.Icons.Entity for visual clarity

**Minor observation (not blocking):**
- iPhone and iPad have duplicated handleFABTap/fabMenuActions code. Acceptable given platform container differences.

**Platform behavior summary:**
| Context | iPhone/iPad | macOS |
|---------|-------------|-------|
| Workspace | Menu: Task, Activity, Listing | Menu: Task, Activity, (divider), Listing |
| Listing List | Direct: opens AddListing | Direct: opens AddListing |
| Listing Detail | Menu: Task, Activity (listing pre-selected) | Default quickEntry |
| Properties | Direct: opens AddProperty | Direct: opens AddProperty |
| Realtor | Menu: Property, Listing (realtor pre-selected) | Default quickEntry |

**Note:** macOS .listingDetail and .realtor contexts fall through to default behavior since context is set at navigation level, not root. This is acceptable as macOS primarily uses keyboard shortcuts for creation.

---

### Implementation Notes

**Context7 Recommended For**:
- SwiftUI environment value patterns (how to properly define and propagate custom environment keys)
- SwiftUI action sheets vs menus vs popovers (platform-appropriate selection UI)
- SwiftUI toolbar customization on macOS

**Testing Strategy**:
- Unit tests for FABContext derivation logic
- UI tests for FAB behavior on each screen type
- Cross-platform verification (iOS Simulator + macOS build)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
