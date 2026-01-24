## Interface Lock

**Feature**: macOS Menu Improvements (Minimum Size + Unified Scrolling)
**Created**: 2026-01-16
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES (UI hierarchy/layout changes, scrolling behavior changes)

### Contract

- **New/changed model fields**: None (UI-only change)
- **DTO/API changes**: None
- **State/actions added**: None (uses existing WindowUIState)
- **UI events emitted**: None
- **Migration required**: N

### Problem Statement

The macOS sidebar menu currently has two issues:

1. **Separate Scroll Regions**: `StageCardsHeader` sits in a `VStack` ABOVE `SidebarDestinationList` (a `List`), creating two independent scroll areas. The stage cards are static while the tab list scrolls independently.

2. **Menu Minimum Size**: While `sidebarMinWidth: 200pt` exists, there is no explicit enforcement of a reasonable menu minimum size that ensures usability.

### Current Architecture (MUST PRESERVE)

The existing system includes:
- `WindowUIState`: Per-window state isolation (sidebar visibility, width, overlay state) - **DO NOT MODIFY**
- `ResizableSidebar`: Custom SwiftUI container with drag handle - **MAY MODIFY INTERNALS**
- Per-window `@State` in `WindowContentView` - **DO NOT MODIFY**
- `SidebarDestinationList`: `List` with `.listStyle(.sidebar)` - **MAY MODIFY**

### Proposed Solution

**Unified Scrolling**: Combine stage cards and tab list into a SINGLE scrollable area. Options:

- **Option A**: Move `StageCardsHeader` INTO the `SidebarDestinationList` as a Section header
- **Option B**: Replace `VStack` + `List` with single `ScrollView` + custom styling
- **Option C**: Use `List` with stage cards as first Section (custom row, not pinned header)

**Recommendation**: Option C - keeps native `List` sidebar behavior while unifying scroll.

**Menu Minimum Size**: The existing `sidebarMinWidth: 200pt` is reasonable. Verify it is enforced correctly during resize operations.

### Acceptance Criteria (3 max)

1. Stage cards and tab list scroll together as a single unified scroll region
2. Sidebar minimum width of 200pt is enforced and cannot be resized smaller (excluding collapse)
3. All changes work with existing `WindowUIState` per-window isolation (multi-window support preserved)

### Non-goals (prevents scope creep)

- No changes to macOS full-screen behavior
- No changes to toolbar or traffic light handling
- No changes to WindowUIState structure
- No changes to iPad or iPhone menu
- No persistence changes (sidebar width reset on app restart is expected)
- No changes to stage card visual design

### Compatibility Plan

- **Backward compatibility**: N/A (no schema/DTO changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert PR if issues arise

### Ownership

- **feature-owner**: Full vertical slice - ContentView sidebar layout, SidebarDestinationList structure, ResizableSidebar constraints
- **data-integrity**: Not needed (no schema changes)

### Implementation Notes

1. **Unified Scrolling Implementation**:
   - Modify `sidebarNavigation` in `/Dispatch/App/ContentView.swift`
   - Change from `VStack { StageCardsHeader; SidebarDestinationList }` to single `List` with stage cards as first Section
   - StageCardsHeader becomes a row/section in the List, not a separate component above it

2. **List Structure Target**:
   ```swift
   List(selection: $sidebarSelection) {
     Section {
       StageCardsSection(stageCounts: stageCounts, onSelectStage: { ... })
     }
     .listRowInsets(...)
     .listRowBackground(...)

     Section {
       ForEach(AppTab.sidebarTabs) { tab in
         SidebarMenuRow(...)
           .tag(SidebarDestination.tab(tab))
       }
     }
   }
   .listStyle(.sidebar)
   ```

3. **Files to Modify**:
   - `/Dispatch/App/ContentView.swift` - `sidebarNavigation` computed property (lines 228-326)
   - `/Dispatch/Features/Menu/Views/Components/SidebarDestinationList.swift` - May need to accept stage cards content or be replaced
   - `/Dispatch/Design/Spacing.swift` - Verify/add any needed spacing tokens

4. **Testing**:
   - Test multi-window: open two windows, verify scroll position is independent per window
   - Test sidebar resize: verify 200pt minimum is respected
   - Test collapse/expand: verify stage cards appear correctly when sidebar is shown

5. **Context7 Usage**: May need for SwiftUI List Section styling, sidebar list patterns

### Files to Modify

1. `/Dispatch/App/ContentView.swift` - Main sidebar layout restructure
2. `/Dispatch/Features/Menu/Views/Components/SidebarDestinationList.swift` - May be modified or inlined
3. `/Dispatch/Design/Spacing.swift` - Verify constraints (likely no changes needed)

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-16 14:30

#### Checklist
- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes
The implementation follows Option C from the contract: stage cards as first Section within native List. This is the correct macOS sidebar pattern.

**What works well:**
- Single `List(selection:)` with `.listStyle(.sidebar)` - exactly what Apple recommends
- Stage cards section uses `listRowBackground(Color.clear)` and `listRowSeparator(.hidden)` for clean integration
- `.scrollContentBackground(.hidden)` removes default List chrome
- Uses DS spacing tokens (`DS.Spacing.sm/md`) for consistent insets
- Selection sync is bidirectional via `.onChange(of:)` handlers
- Multi-window state preserved (per contract requirement)

**Would Apple ship this?** Yes. This is how Finder, Notes, and other macOS apps structure their sidebars - grouped sections within a single scrollable List.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
