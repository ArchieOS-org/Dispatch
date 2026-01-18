## Interface Lock

**Feature**: macOS Multi-Window State Isolation + Duplicate Button
**Created**: 2026-01-16
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES (new title bar button, customer-facing UI change)

### Contract

- **New/changed model fields**: None (UI-only change)
- **DTO/API changes**: None
- **State/actions added**:
  - `WindowUIState`: Per-window observable state container holding:
    - `sidebarVisible: Bool` (default: true)
    - `sidebarWidth: CGFloat` (default: 240)
    - `isDragging: Bool` (transient)
  - `AppCommand.duplicateWindow`: New command to duplicate current window
  - Remove `@AppStorage` from `SidebarState` (becomes window-scoped)
  - Move search overlay state (`overlayState.search`) to per-window scope
- **UI events emitted**: None
- **Migration required**: N (in-memory state only, no persistence change needed)

### Acceptance Criteria (3 max)

1. Opening search (Cmd+F) in Window A does NOT affect Window B's search state
2. Resizing/collapsing sidebar in Window A does NOT affect Window B's sidebar
3. Clicking "Duplicate" button creates a new window showing the same destination/route

### Non-goals (prevents scope creep)

- No persistence of per-window layout across app restarts (sidebar width resets to default)
- No window title customization
- No iOS/iPadOS changes (macOS-only feature)
- No window position/size memory per window

### Compatibility Plan

- **Backward compatibility**: N/A (no schema/DTO changes)
- **Default when missing**: New windows start with default sidebar visible at 240pt
- **Rollback strategy**: Revert to global `@AppStorage` if issues arise

### Ownership

- **feature-owner**: Full vertical slice - WindowUIState, SidebarState refactor, ContentView per-window injection, duplicate button in toolbar
- **data-integrity**: Not needed (no schema changes)

### Implementation Notes

1. **WindowUIState Pattern**: Use SwiftUI's `@State` at WindowGroup content level, passed down via environment. Each window instance gets its own state.

2. **SidebarState Refactor**:
   - Remove `@AppStorage` decorators
   - Make `SidebarState` a simple `@Observable` class
   - Create instance per-window, not globally

3. **Search Overlay Isolation**:
   - The `overlayState` in `AppState` currently controls search visibility globally
   - Option A: Move overlay state to per-window `WindowUIState`
   - Option B: Use `FocusedValue` to scope overlay to focused window
   - Recommendation: Option A for simplicity

4. **Duplicate Button**:
   - Add toolbar button with `ToolbarItem(placement: .navigation)` or custom title bar view
   - Use `@Environment(\.openWindow)` with the same window group but pass current route
   - Button should use SF Symbol "plus.rectangle.on.rectangle" or similar

5. **Context7 Recommendation**: Use for SwiftUI multi-window patterns, `@Environment(\.openWindow)` usage

### Files to Modify

1. `/Dispatch/Foundation/Platform/macOS/SidebarState.swift` - Remove @AppStorage, make window-scoped
2. `/Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` - Accept SidebarState via environment
3. `/Dispatch/App/ContentView.swift` - Create per-window state, inject via environment
4. `/Dispatch/App/Shell/AppShellView.swift` - Add duplicate button to toolbar
5. `/Dispatch/App/DispatchApp.swift` - May need WindowGroup ID for openWindow

### New Files

1. `/Dispatch/Foundation/Platform/macOS/WindowUIState.swift` - Per-window state container (optional - could inline in ContentView)

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
The Duplicate Window button implementation is clean, minimal, and follows macOS conventions:

1. **Icon choice is appropriate**: "plus.rectangle.on.rectangle" clearly communicates "add another window" - matches macOS system patterns
2. **Label is clear**: "New Window" is unambiguous
3. **Tooltip is helpful**: "Open New Window" provides context without being verbose
4. **Placement is correct**: `.navigation` puts it in the leading toolbar area, appropriate for window-level actions
5. **Edge case handled**: `.disabled(!supportsMultipleWindows)` gracefully handles environments that don't support multiple windows
6. **Code organization is clean**: Separate `DuplicateWindowButton` struct keeps the code readable

Would Apple ship this? Yes - this matches the pattern seen in Finder, Safari, and other Apple apps for window management.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
