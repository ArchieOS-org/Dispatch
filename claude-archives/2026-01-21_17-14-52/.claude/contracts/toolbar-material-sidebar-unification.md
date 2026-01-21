## Interface Lock

**Feature**: Native Toolbar Transparency & iPad/macOS Sidebar Unification
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles on iOS + macOS | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Cross-platform validation | xcode-pilot |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. Toolbar uses native `Material.thin` (or equivalent) across iOS, iPad, macOS - no hardcoded colors; content scrolls beneath with blur effect visible
2. iPad and macOS sidebars share 80%+ implementation via a unified `UnifiedSidebar` component that adapts to platform; selection states, spacing, typography match
3. Light/dark mode works automatically via semantic colors and native materials; no manual color switching

### Non-goals (prevents scope creep)

- No changes to sidebar navigation destinations or structure
- No new sidebar items or tabs
- No changes to FAB or floating button behavior
- No changes to stage cards header functionality
- No toolbar button/action changes (only background/material)

### Compatibility Plan

- **Backward compatibility**: N/A (UI-only changes)
- **Default when missing**: N/A
- **Rollback strategy**: Revert unified component; restore platform-specific implementations

---

### Ownership

- **feature-owner**: End-to-end implementation of toolbar material and unified sidebar
- **data-integrity**: Not needed

---

### Files Likely Modified

**Part 1: Toolbar Transparency**
- `Dispatch/Foundation/Platform/macOS/BottomToolbar.swift` - macOS toolbar material
- `Dispatch/App/Shell/StandardScreen.swift` - iOS toolbar appearance
- `Dispatch/App/Shell/AppShellView.swift` - Shell-level toolbar config

**Part 2: Sidebar Unification**
- `Dispatch/App/Platform/iPadContentView.swift` - Extract sidebar to unified component
- `Dispatch/App/Platform/MacContentView.swift` - Use unified sidebar component
- `Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` - Extend for iPad compatibility
- `Dispatch/Design/Shared/Components/SidebarMenuRow.swift` - Platform-adaptive styling
- NEW: `Dispatch/Design/Shared/Components/UnifiedSidebar.swift` - Shared sidebar component
- `Dispatch/Design/Spacing.swift` - Add sidebar spacing tokens if needed

**Design System Updates**
- `DESIGN_SYSTEM.md` - Document new sidebar patterns and material usage

---

### Implementation Notes

**Context7 Required For:**
- SwiftUI Material documentation (Material.thin, Material.regular thickness levels)
- Apple Sidebars HIG (selection states, spacing guidelines)
- UIToolbar scrollEdgeAppearance (UIKit bridge if needed)
- NavigationSplitView sidebar styling

**Key Technical Decisions:**

1. **Toolbar Material**: Use `.background(Material.thin)` for SwiftUI, ensure `ignoresSafeArea()` to extend under nav bar

2. **Sidebar Unification Strategy**:
   - Create `UnifiedSidebar<Content: View>` that handles:
     - Material background (`.thinMaterial`)
     - Selection highlighting via `List(selection:)`
     - Platform-adaptive spacing using `#if os(iOS)` only for touch targets
     - Safe area handling for Dynamic Island/notch
   - iPad: Use inside NavigationSplitView or custom split
   - macOS: Use inside ResizableSidebar container

3. **Platform Divergence Points** (minimal):
   - macOS: Resizable via drag handle (existing ResizableSidebar)
   - iPad: Fixed width via NavigationSplitView or TabView sidebarAdaptable
   - Both: Same visual styling, same row components

4. **Materials vs Colors**:
   - Sidebar background: `.thinMaterial` (not `.secondary`)
   - Toolbar background: `.regularMaterial` for macOS bottom bar, `.thinMaterial` for nav toolbar
   - Selection: System selection style (no custom colors)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Material background toolbar transparency blur thinMaterial regularMaterial ultraThinMaterial sidebar
CONTEXT7_TAKEAWAYS:
- Use `Material.thin`, `Material.regular`, or `Material.ultraThin` for blur effects
- Apply via `.background(.regularMaterial)` or `.fill(Material.thin)`
- Materials are available on iOS 15.0+, macOS 12.0+
- Use `.ignoresSafeArea()` to extend material under safe areas
CONTEXT7_APPLIED:
- `.thinMaterial` sidebar background -> UnifiedSidebar.swift:body
- `.regularMaterial` toolbar background -> BottomToolbar.swift:67 (already present)

CONTEXT7_QUERY: NavigationSplitView sidebar columnVisibility style listStyle sidebar three column
CONTEXT7_TAKEAWAYS:
- NavigationSplitView supports programmatic column visibility control
- Use `NavigationSplitViewVisibility` binding for visibility state
- Available on iOS 16.0+, macOS 13.0+
CONTEXT7_APPLIED:
- NavigationSplitView with columnVisibility -> iPadContentView.swift:45

CONTEXT7_QUERY: List selection sidebar style scrollContentBackground hidden background material
CONTEXT7_TAKEAWAYS:
- Use `.scrollContentBackground(.hidden)` to hide default List background
- This allows custom material backgrounds to show through
- On macOS 15+, helps achieve seamless titlebar appearance
CONTEXT7_APPLIED:
- `.scrollContentBackground(.hidden)` -> UnifiedSidebar.swift:body

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Material background toolbar transparency | `.thinMaterial` / `.regularMaterial` with `.ignoresSafeArea()` |
| NavigationSplitView sidebar styling | `NavigationSplitView(columnVisibility:)` with binding |
| List selection sidebar background | `.scrollContentBackground(.hidden)` for custom backgrounds |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 14:30

#### Checklist

- [x] Ruthless simplicity - Single UnifiedSidebarContent serves both platforms, 85%+ code sharing, minimal platform divergence
- [x] One clear primary action per screen/state - Selection states obvious via system List(selection:), stage cards provide visual entry
- [x] Strong hierarchy - Stage cards (prominent) at top, navigation tabs below, proper DS.Typography usage
- [x] No clutter - Clean List with sidebar style, material background creates breathing room
- [x] Native feel - Uses .listStyle(.sidebar), .thinMaterial, NavigationSplitView on iPad, Things 3-style ResizableSidebar on macOS

#### Verdict Notes

Implementation meets all design criteria:

1. **Material blur**: Correctly uses `.thinMaterial` on both platforms with `.scrollContentBackground(.hidden)` to allow material to show through
2. **Visual consistency**: Same UnifiedSidebarContent component, same typography (DS.Typography tokens), same icon sizing via SidebarMenuRow
3. **Behavior consistency**: System selection via List(selection:), proper optional bridging for stage destinations
4. **Code sharing**: 85%+ achieved - only container differs (NavigationSplitView vs ResizableSidebar)
5. **Light/dark mode**: Automatic via semantic materials and colors - no hardcoded values
6. **Safe areas**: Properly handled via `.ignoresSafeArea(.all, edges: .all)` on material background
7. **Accessibility**: Section labels, Dynamic Type support, 44pt touch targets on iOS
8. **Design system**: New "Sidebar Patterns" section added to DESIGN_SYSTEM.md

Would Apple ship this? **YES.** The implementation follows HIG materials guidance, uses native platform navigation patterns, and achieves code sharing without sacrificing platform-appropriate behavior.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
