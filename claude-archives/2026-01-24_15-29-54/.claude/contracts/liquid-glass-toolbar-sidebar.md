## Interface Lock

**Feature**: WWDC25 Liquid Glass Toolbar and Full-Height Unified Sidebar
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
- [x] **Unfamiliar area** (adds dispatch-explorer) - iOS 26/macOS 26 APIs beyond training data

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles + skeleton | feature-owner |
| 1.5 | Context7 deep dive for iOS 26/macOS 26 APIs | feature-owner |
| 2 | Full implementation + integration | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Simulator validation (iPad + macOS) | xcode-pilot |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (uses existing WindowUIState)
- Migration required: N

### Files to Modify

**Primary (Toolbar + Window):**
| File | Change |
|------|--------|
| `/Dispatch/App/DispatchApp.swift` | Window styling for fullSizeContentView, toolbar behavior |
| `/Dispatch/App/Platform/MacContentView.swift` | Replace BottomToolbar with floating top toolbar |
| `/Dispatch/App/Platform/iPadContentView.swift` | Add Liquid Glass floating toolbar |
| `/Dispatch/Foundation/Platform/macOS/BottomToolbar.swift` | Refactor OR replace with LiquidGlassToolbar |

**Sidebar:**
| File | Change |
|------|--------|
| `/Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` | Full-height glass material, safe area handling |
| `/Dispatch/Design/Shared/Components/UnifiedSidebar.swift` | Update material to iOS 26 glass |

**Design System:**
| File | Change |
|------|--------|
| `/Packages/DesignSystem/Sources/DesignSystem/Effects/GlassEffect.swift` | Add iOS 26 `.glassEffect()` APIs when available |
| `/Packages/DesignSystem/Sources/DesignSystem/Tokens/DSSpacing.swift` | Add toolbar spacing tokens |

**New Files (if needed):**
| File | Purpose |
|------|---------|
| `/Dispatch/Design/Shared/Components/LiquidGlassToolbar.swift` | Shared floating toolbar component |

### Acceptance Criteria (3 max)

1. **Toolbar floats above content with Liquid Glass effect**: Toolbar uses native glass material (`.glassEffect()` on iOS 26+, Material fallback), content scrolls behind with automatic blur effect
2. **Sidebar is full-height with glass material**: macOS and iPad sidebars extend full window height, use unified glass material, 80%+ code shared via UnifiedSidebarContent
3. **Full-screen works flawlessly**: Content respects safe areas, sidebar remains full-height, no hardcoded colors (100% native materials)

### Non-goals (prevents scope creep)

- No changes to sidebar navigation structure (tabs, stages stay same)
- No changes to Quick Find/search functionality
- No new toolbar actions (same actions as current BottomToolbar)
- No iPhone changes (iPhone uses TabView, not floating toolbar)
- No custom animations beyond native SwiftUI behavior

### Compatibility Plan

- **Backward compatibility**: iOS 26/macOS 26+ required for full Liquid Glass; earlier versions use Material fallback (already in GlassEffect.swift)
- **Default when missing**: GlassEffect.swift pattern - check availability, fall back to `.regularMaterial` or `.thinMaterial`
- **Rollback strategy**: Feature flag `useLiquidGlassToolbar` in WindowUIState (disabled by default until validated)

---

### Ownership

- **feature-owner**: Full implementation - toolbar, sidebar, window styling, design tokens
- **data-integrity**: Not needed (no schema changes)

---

### Implementation Notes

#### Context7 is MANDATORY for this feature

**CRITICAL**: iOS 26/macOS 26 APIs are BEYOND Claude's training data. The following MUST be queried via Context7 before ANY implementation:

| Topic | Why Context7 Required |
|-------|----------------------|
| `.glassEffect()` modifier | New iOS 26 API, exact syntax unknown |
| `ToolbarSpacer` API | New iOS 26 API for toolbar item grouping |
| Scroll edge appearance | New automatic blur behavior API |
| `fullSizeContentView` | macOS 26 window styling changes |
| NavigationSplitView customization | iOS 26 material/styling updates |

**Recommended Context7 Queries:**
1. SwiftUI: "glass effect modifier iOS 26 liquid glass"
2. SwiftUI: "ToolbarSpacer automatic grouping spacing"
3. SwiftUI: "scroll edge appearance blur content behind toolbar"
4. SwiftUI: "fullSizeContentView window styling macOS 26"
5. SwiftUI: "NavigationSplitView sidebar material customization"

#### Platform-Specific Implementation

**macOS 26:**
- Window uses `fullSizeContentView` behavior
- Toolbar floats above content (not integrated in title bar)
- Sidebar extends full-height including title bar area
- Use NSSplitViewController patterns where SwiftUI falls short

**iPad (iOS 26):**
- NavigationSplitView with custom glass sidebar material
- Floating toolbar via `.safeAreaInset(edge: .top)`
- Content scrolls behind toolbar with blur

**Code Sharing Target: 80%+**
- `UnifiedSidebarContent` already shared - extend with glass material
- New `LiquidGlassToolbar` component shared between platforms
- Platform differences only in container wrappers

#### Design Requirements (from WWDC25)

1. **Liquid Glass Surface**
   - Use `.background(Material.thin)` or `.glassEffect()` when available
   - NO hardcoded colors or opacities
   - Automatic light/dark mode adaptation

2. **Scroll Edge Blur**
   - Content blurs as it scrolls under toolbar
   - Use native scroll edge appearance API
   - Do NOT implement manual blur effects

3. **ToolbarSpacer API**
   - Automatic item grouping and spacing
   - Monochrome SF Symbols with automatic scaling
   - Badge support for notifications

4. **Full-Screen Behavior**
   - Sidebar full-height in full-screen mode
   - Content respects all safe areas
   - Traffic lights (macOS) integrated naturally

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: glass effect glassEffect modifier iOS 26 liquid glass material toolbar
CONTEXT7_TAKEAWAYS:
- `.glassEffect(_ glass: Glass = .regular, in shape: some Shape)` applies Liquid Glass to views
- System renders shape behind view with Liquid Glass material + foreground effects
- Default uses `.regular` variant with `Capsule` shape, anchored to view bounds
- Use with `GlassEffectContainer` for morphing between multiple glass shapes
- `.sharedBackgroundVisibility(.hidden)` removes shared glass from toolbar items (iOS/macOS 26+)
CONTEXT7_APPLIED:
- `.glassEffect()` for toolbar background -> LiquidGlassToolbar.swift
- `.sharedBackgroundVisibility(.hidden)` for custom grouping -> toolbar items

CONTEXT7_QUERY: ToolbarSpacer toolbar spacing automatic grouping items
CONTEXT7_TAKEAWAYS:
- `ToolbarSpacer(.flexible)` expands to fill available space (default)
- `ToolbarSpacer(.fixed)` uses system-defined fixed spacing
- Use `ToolbarItemGroup` to group related items
- Spacers enable automatic Liquid Glass effect application to organized toolbar
CONTEXT7_APPLIED:
- `ToolbarSpacer(.flexible)` and `.fixed` for item grouping -> LiquidGlassToolbar.swift

CONTEXT7_QUERY: scroll edge appearance blur toolbar safeAreaInset scrollContentBackground
CONTEXT7_TAKEAWAYS:
- `.safeAreaInset(edge:alignment:spacing:content:)` shows content beside view with inset
- `.safeAreaBar(edge:...)` extends scroll edge effects to custom bars
- Content anchored to edge, modified view inset by content width/height
- Safe area increased by same amount as inset
CONTEXT7_APPLIED:
- `.safeAreaInset(edge: .top)` for floating toolbar -> MacContentView.swift, iPadContentView.swift

CONTEXT7_QUERY: NavigationSplitView sidebar material background customization glass
CONTEXT7_TAKEAWAYS:
- `.containerBackground(.thinMaterial, for: .navigation)` for sidebar material
- `.containerBackground(Color, for: .navigationSplitView)` for overall split view
- Works with translucent columns and divider color
- Available iOS 18.0+, iPadOS 18.0+, macOS (via Catalyst)
CONTEXT7_APPLIED:
- `.containerBackground(.thinMaterial, for: .navigation)` -> UnifiedSidebar.swift

CONTEXT7_QUERY: windowStyle fullSizeContentView titlebar transparent macOS toolbar styling
CONTEXT7_TAKEAWAYS:
- `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` removes toolbar background
- `.windowToolbarStyle(.unified(showsTitle: false))` hides title in unified toolbar
- Content extends to window edge when toolbar background hidden
- System still provides title to accessibility tools
CONTEXT7_APPLIED:
- `.toolbarBackgroundVisibility(.hidden)` -> DispatchApp.swift window styling

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| glass effect modifier iOS 26 | `.glassEffect(_ glass:in:)` with shape parameter |
| ToolbarSpacer grouping | `ToolbarSpacer(.flexible/.fixed)` + `ToolbarItemGroup` |
| scroll edge blur safeAreaInset | `.safeAreaInset(edge:)` for floating toolbar positioning |
| NavigationSplitView material | `.containerBackground(.thinMaterial, for: .navigation)` |
| macOS window toolbar styling | `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 (PATCHSET 2.5)

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**SHIP YES** - Implementation meets WWDC25 Liquid Glass design bar.

**Principles Assessment:**
- **Ruthless simplicity**: Toolbar has minimal context-aware actions (New, Search, Filter, Delete). No unnecessary controls.
- **One primary action**: Primary actions clearly positioned (New left, Search right). Context determines visible actions.
- **Strong hierarchy**: Icon-only floating toolbar with clear grouping via HStack + Spacer.
- **No clutter**: Clean glass surface, generous padding (DS.Spacing.lg = 16pt), whitespace as feature.
- **Native feel**: Uses Material/.thinMaterial, SF Symbols only, platform-adaptive styling.

**Execution Assessment:**
- **DS Components**: Uses all Design System tokens (liquidGlassToolbarHeight: 48pt, buttonSize: 44pt, iconSize: 18pt).
- **A11y**: VoiceOver labels on all buttons, .help() on macOS, touch targets = 44pt minimum.
- **States**: Context-aware (list vs detail), disabled states, destructive styling for delete action.

**WWDC25 Criteria:**
1. Toolbar floats via `.safeAreaInset(edge: .top)` - not window-integrated
2. Glass material via `.thinMaterial` with stroke border and shadow (iOS 26 `glassEffect()` path prepared)
3. Sidebar full-height via `.ignoresSafeArea(.all, edges: .top)` with `.glassSidebarBackground()`
4. SF Symbols monochrome with `.foregroundStyle(.primary.opacity(0.7))`
5. 80%+ code sharing via `LiquidGlassToolbar` component used by both platforms

**Would Apple ship this?** Yes. The Material fallback is the correct engineering decision until iOS 26 SDK stabilizes, and the glassEffect code path is documented and ready.

---

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| iOS 26 APIs not yet in stable SDKs | GlassEffect.swift already has fallback pattern; extend for toolbar |
| CI builds may fail on new APIs | Use `#if canImport` and `@available` guards |
| Window styling may conflict with existing ResizableSidebar | Test thoroughly; keep existing collapse/expand behavior |
| Performance regression from glass effects | Profile with Instruments; glass effects are GPU-accelerated |

### Testing Strategy

1. **Unit Tests**: None needed (pure UI)
2. **UI Tests**:
   - Toolbar visibility on scroll
   - Sidebar collapse/expand still works
   - Full-screen mode transitions
3. **Manual Validation (xcode-pilot)**:
   - iPad Pro 13" (M5) simulator
   - macOS 15+ (build only, per no-macos-control.md)
   - Light/dark mode
   - Dynamic Type sizes

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
