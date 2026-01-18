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
**Reviewed**: 2026-01-18 (updated)

#### Checklist
- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes (Updated for Bottom Toolbar Relocation)

The Duplicate Window button has been moved from the top toolbar to the bottom toolbar. This change improves the design:

1. **Icon choice is appropriate**: "square.on.square" is standard macOS iconography for window duplication
2. **Placement improved**: Moving from top toolbar (with visible background) to bottom toolbar (icon-only) eliminates visual inconsistency
3. **Follows Things 3 pattern**: Secondary utility actions (search, duplicate window) grouped on the right side of bottom toolbar
4. **Uses ToolbarIconButton**: Consistent with other bottom toolbar buttons - 36pt size, .buttonStyle(.plain), no background, hover states
5. **Tooltip preserved**: .help() provides "Opens a new window with independent sidebar and search state"
6. **Keyboard shortcut intact**: Cmd+Shift+N still works
7. **Disabled state handled**: supportsMultipleWindows check preserved

**Design System Compliance**:
- Uses DS.Spacing.bottomToolbarButtonSize (36pt)
- Uses DS.Spacing.bottomToolbarIconSize (18pt)
- Uses DS.Spacing.bottomToolbarPadding (12pt)
- Uses DS.Spacing.bottomToolbarHeight (44pt)

Would Apple ship this? Yes - Things 3 uses this exact pattern for utility toolbar actions.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
