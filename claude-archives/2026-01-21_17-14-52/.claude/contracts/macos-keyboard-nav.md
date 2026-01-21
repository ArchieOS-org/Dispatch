## Interface Lock

**Feature**: macOS Keyboard Navigation
**Created**: 2025-01-18
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

**Rationale**: This feature adds keyboard shortcuts for macOS list navigation. No visual UI changes - purely interaction layer. Existing patterns (`.onKeyPress`, `.keyboardShortcut`) are well-established in the codebase.

### Patchset Plan

Based on checked indicators (none):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met, manual verification | feature-owner, integrator |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: New AppCommand cases for keyboard navigation (optional - may use existing)
- Migration required: N

### Technical Approach

1. **Arrow key navigation (up/down)**: SwiftUI List with `selection:` binding on macOS typically provides native arrow key support. Verify this works, or add explicit `.onKeyPress(.upArrow)` / `.onKeyPress(.downArrow)` handlers if needed.

2. **Escape to pop navigation**: Add `.onKeyPress(.escape)` handler in MacContentView content area that:
   - Calls `appState.dispatch(.popToRoot(appState.router.selectedDestination))` to pop navigation stack
   - Should only handle when navigation stack is not empty

3. **Enter/Return to open selected item**: If native List selection doesn't auto-navigate on Enter, add `.onKeyPress(.return)` handler to navigate to selected item.

4. **Cmd+E for edit**: Add to DispatchCommands with `.keyboardShortcut("e", modifiers: .command)`. Context-dependent - should open edit sheet for currently viewed entity.

5. **Document shortcuts in menu**: Add menu items to DispatchCommands that show the keyboard shortcuts (even if disabled/informational). Standard macOS pattern is to have menu items that show shortcuts.

### Files to Modify

| File | Changes |
|------|---------|
| `Dispatch/App/Platform/MacContentView.swift` | Add arrow key, Escape, Enter key handlers |
| `Dispatch/App/State/DispatchCommands.swift` | Add Cmd+E, document navigation shortcuts in menu |
| `Dispatch/App/State/AppCommand.swift` | Add edit command case (if needed) |

### Acceptance Criteria (3 max)

1. Arrow keys navigate list items (up/down selection changes)
2. Escape pops navigation stack (returns to list from detail view)
3. Enter/Return opens selected item (navigates to detail view)

### Extended Criteria (must also pass)

4. Cmd+E triggers edit for applicable contexts
5. Shortcuts visible in menu bar
6. No conflicts with system shortcuts (Cmd+C, Cmd+V, Cmd+Q, etc.)
7. CI passes, no regressions

### Non-goals (prevents scope creep)

- No custom focus ring styling
- No Tab key navigation between sections
- No multi-select support
- No keyboard shortcuts for iOS/iPadOS (macOS only)

### Compatibility Plan

- **Backward compatibility**: N/A - new functionality only
- **Default when missing**: N/A
- **Rollback strategy**: Revert PR - no data changes

---

### Ownership

- **feature-owner**: Implement all keyboard navigation in MacContentView and DispatchCommands
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: onKeyPress modifier for handling arrow keys escape return keyboard events macOS
CONTEXT7_TAKEAWAYS:
- `onKeyPress(_:action:)` takes KeyEquivalent and returns KeyPress.Result (.handled or .ignored)
- Available on macOS 14.0+, iOS 17.0+
- Use `phases: .down` to handle key-down events only
- Return `.handled` to consume event, `.ignored` to allow further dispatch
CONTEXT7_APPLIED:
- `.onKeyPress(.escape)` handler -> MacContentView.swift:223

CONTEXT7_QUERY: keyboardShortcut modifier menu commands with modifiers
CONTEXT7_TAKEAWAYS:
- `.keyboardShortcut(_:modifiers:)` takes KeyEquivalent and EventModifiers
- Default modifier is `.command`
- Use `.escape` KeyEquivalent for Escape key (no modifiers)
- Use `"e"` with `.command` for Cmd+E
CONTEXT7_APPLIED:
- `.keyboardShortcut(.escape, modifiers: [])` -> DispatchCommands.swift:87
- `.keyboardShortcut("e", modifiers: .command)` -> DispatchCommands.swift:94

CONTEXT7_QUERY: KeyEquivalent escape return upArrow downArrow special keys
CONTEXT7_TAKEAWAYS:
- `KeyEquivalent.escape` (U+001B) - Escape key
- `KeyEquivalent.return` (U+000D) - Return key
- `KeyEquivalent.upArrow` (U+F700) - Up Arrow key
- `KeyEquivalent.downArrow` (U+F701) - Down Arrow key
CONTEXT7_APPLIED:
- `.escape` KeyEquivalent for navigation back -> DispatchCommands.swift:87

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| onKeyPress modifier for keyboard events | `.onKeyPress(.escape) { ... }` with KeyPress.Result |
| keyboardShortcut with modifiers | `.keyboardShortcut(.escape, modifiers: [])` and `.keyboardShortcut("e", modifiers: .command)` |
| KeyEquivalent special keys | `KeyEquivalent.escape`, `.return`, `.upArrow`, `.downArrow` static properties |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A
**Reviewed**: N/A

**Note**: UI Review Required is NO because this feature adds keyboard interaction only, with no visual changes to the interface. Jobs Critique is not required.

---

### Implementation Notes

**Context7 Recommendation**: Query SwiftUI docs for:
- `onKeyPress` modifier for handling keyboard events
- `keyboardShortcut` for menu item shortcuts
- List selection behavior on macOS

**Existing Patterns to Follow**:
- MacContentView lines 205-218: existing `.onKeyPress(characters: .alphanumerics)` pattern
- DispatchCommands: existing `.keyboardShortcut()` pattern with modifiers

**System Shortcut Conflicts to Avoid**:
- Cmd+C (Copy), Cmd+V (Paste), Cmd+X (Cut)
- Cmd+Z (Undo), Cmd+Shift+Z (Redo)
- Cmd+Q (Quit), Cmd+W (Close Window)
- Cmd+H (Hide), Cmd+M (Minimize)
- Escape (may conflict with sheet dismissal - handle gracefully)

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
