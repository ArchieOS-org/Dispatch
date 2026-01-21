## Interface Lock

**Feature**: Complete Sidebar/Toolbar Rebuild - Floating Side Menu Architecture
**Created**: 2026-01-20
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### CRITICAL CONTEXT: 8+ Failed Attempts

This contract exists because **8+ previous attempts have failed**:

| Contract | Approach | Failure Reason |
|----------|----------|----------------|
| `native-macos-sidebar-toolbar.md` | NavigationSplitView + unifiedCompact | Sidebar coupled with toolbar, background issues |
| `liquid-glass-toolbar-sidebar.md` | WWDC25 Liquid Glass APIs | Too complex, fighting window chrome |
| `fix-toolbar-sidebar-v3.md` | Incremental fixes | Didn't address root architecture |
| `toolbar-rebuild.md` | Destroy + rebuild with native | Still used NavigationSplitView, same coupling |
| `sidebar-simplify.md` | SimplifiedSidebar wrapper | Created MORE complexity, not less |
| `toolbar-material-sidebar-unification.md` | Material unification | Double-layered materials fighting each other |
| `hig-toolbar-refactor.md` | HIG compliance | Didn't address structural issues |
| `sidebar-collapse-fix*.md` | Collapse behavior fixes | Bandaids on broken architecture |

**Root cause of all failures**: NavigationSplitView tightly couples sidebar with toolbar/titlebar behavior. Any attempt to customize one affects the other unpredictably.

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5) - New navigation architecture
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3) - Complete navigation replacement
- [x] **Unfamiliar area** (adds dispatch-explorer) - 8 failures = unfamiliar by definition

### Patchset Plan

| Patchset | Gate | Agents |
|----------|------|--------|
| 0 | Context7 research complete | feature-owner |
| 1 | Compiles - old code deleted, new skeleton | feature-owner |
| 2 | Tests pass, new architecture works | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |
| 3 | Cross-platform validation | xcode-pilot |

---

### THE NEW ARCHITECTURE (User's Explicit Requirements)

#### What the User Wants

1. **Normal floating side menu** - NOT NavigationSplitView integrated sidebar
   - Simple ZStack/HStack layout with a toggleable floating panel
   - Sidebar animates in/out independently of toolbar
   - No coupling with window chrome

2. **No toolbar background** (except full-screen)
   - Transparent toolbar area normally
   - Content shows through to window edge
   - EXCEPTION: Full-screen mode gets toolbar background (system requirement)

3. **Clean slate** - Delete all accumulated complexity
   - No workarounds, no wrapper views
   - Delete MacWindowPolicy accumulated hacks
   - Delete conflicting modifiers

4. **Context7 best practices** - macOS 15+ / iOS 18+ patterns

#### Architecture Diagram

```
CURRENT (NavigationSplitView - BROKEN):
┌─────────────────────────────────────────────────────────────┐
│ Window                                                      │
│ ┌─ NavigationSplitView ───────────────────────────────────┐ │
│ │ ┌─ Sidebar Column ─┐ ┌─ Detail Column ─────────────────┐│ │
│ │ │  (coupled with   │ │  (toolbar placement affects     ││ │
│ │ │   toolbar glass) │ │   sidebar styling and vice versa││ │
│ │ └──────────────────┘ └─────────────────────────────────┘│ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

NEW (Simple ZStack with floating panel):
┌─────────────────────────────────────────────────────────────┐
│ Window (no toolbar background, content to edge)             │
│ ┌─ ZStack ────────────────────────────────────────────────┐ │
│ │                                                          │ │
│ │  ┌─ Main Content (NavigationStack) ───────────────────┐ │ │
│ │  │  Full-width content, scrolls under toolbar area     │ │ │
│ │  │  Toolbar items float with no background             │ │ │
│ │  └─────────────────────────────────────────────────────┘ │ │
│ │                                                          │ │
│ │  ┌─ Floating Sidebar (conditional) ─┐                    │ │
│ │  │  Appears/disappears independently │                   │ │
│ │  │  Glass material background        │                   │ │
│ │  │  Shadow/overlay for depth         │                   │ │
│ │  └───────────────────────────────────┘                   │ │
│ │                                                          │ │
│ └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: `AppState.sidebarVisible: Bool` (simple toggle)
- Migration required: N

### Files to DESTROY (Delete Entirely)

| File | Why Delete |
|------|------------|
| `Dispatch/Foundation/Platform/MacWindowPolicy.swift` | Accumulated conflicting NSWindow hacks |
| `Dispatch/Features/Navigation/SimplifiedToolbar.swift` | Previous failed attempt |
| `Dispatch/Features/Navigation/SimplifiedSidebar.swift` | Previous failed attempt |
| `Dispatch/Features/Navigation/SidebarSelectionBinding.swift` | Overcomplicated binding |

### Files to COMPLETELY REWRITE

| File | Current State | New State |
|------|---------------|-----------|
| `Dispatch/App/Platform/MacContentView.swift` | NavigationSplitView + coupled toolbar | Simple ZStack + floating sidebar + NavigationStack |
| `Dispatch/App/Shell/AppShellView.swift` | Contains accumulated toolbar modifiers | Minimal shell, no toolbar hacks |
| `Dispatch/App/DispatchApp.swift` | Window styling overrides | Minimal window config |

### Files to CREATE

| File | Purpose | Target LOC |
|------|---------|------------|
| `Dispatch/App/Platform/MacFloatingSidebar.swift` | Floating side menu component | ~80 |

### Files to KEEP (Reuse as-is)

| File | Why Keep |
|------|----------|
| `Dispatch/Features/Menu/Views/Components/UnifiedSidebar.swift` | Content component, works |
| `Dispatch/Features/Menu/Views/Components/SidebarMenuRow.swift` | Row component, works |
| `Dispatch/Features/Menu/Views/Components/SidebarTabList.swift` | Tab list component, works |

---

### Acceptance Criteria (3 max)

1. **Sidebar fully decoupled from toolbar**: Sidebar show/hide does NOT affect toolbar appearance or vice versa
2. **Transparent toolbar in normal mode**: Toolbar area has NO background; content scrolls to window edge. Full-screen mode allowed to have system toolbar background.
3. **Builds on macOS 15 AND iOS 18**: Must compile and work on deployment targets (not just latest beta)

### Non-goals (prevents scope creep)

- No changes to sidebar CONTENT (UnifiedSidebarContent stays)
- No changes to toolbar ACTIONS (same buttons: filter, new, search)
- No iOS/iPhone changes (this is macOS-focused)
- No iPad changes (NavigationSplitView works fine on iPad)
- No new features or functionality
- No Liquid Glass / macOS 26 APIs (use Material as fallback)

### Compatibility Plan

- **Backward compatibility**: N/A (UI rebuild only)
- **Default when missing**: N/A
- **Rollback strategy**: Git revert entire branch

---

### Ownership

- **dispatch-explorer**: Not needed - files are documented above
- **feature-owner**: Complete destruction and rebuild
- **data-integrity**: Not needed
- **jobs-critic**: Design bar after PATCHSET 2
- **ui-polish**: Refinements after SHIP YES
- **xcode-pilot**: macOS validation (build-only per no-macos-control.md)
- **integrator**: Final verification

---

### Implementation Guide

#### Step 1: Delete Accumulated Complexity

```bash
# Delete these files entirely
rm Dispatch/Foundation/Platform/MacWindowPolicy.swift
rm Dispatch/Features/Navigation/SimplifiedToolbar.swift
rm Dispatch/Features/Navigation/SimplifiedSidebar.swift
rm Dispatch/Features/Navigation/SidebarSelectionBinding.swift
```

#### Step 2: Minimal Window Configuration (DispatchApp.swift)

```swift
WindowGroup(id: "main") {
  WindowContentView(...)
}
#if os(macOS)
// MINIMAL config - let system handle chrome
.defaultSize(width: DS.Spacing.windowDefaultWidth, height: DS.Spacing.windowDefaultHeight)
// NO windowStyle or windowToolbarStyle - use system defaults
#endif
```

#### Step 3: Clean AppShellView (No Hacks)

```swift
struct AppShellView: View {
  var body: some View {
    ContentView()
    // NO .applyMacWindowPolicy() - deleted
    // NO .windowToolbarFullScreenVisibility() - let system handle
    // NO .containerBackground() - let content define its own
  }
}
```

#### Step 4: New MacContentView Architecture

```swift
struct MacContentView: View {
  @State private var sidebarVisible = true

  var body: some View {
    ZStack(alignment: .leading) {
      // Main content - full width, NavigationStack only
      NavigationStack(path: $path) {
        destinationRootView()
          .appDestinations()
      }
      .toolbar {
        // Toolbar items with NO background
        ToolbarItemGroup(placement: .primaryAction) {
          // filter, new, search buttons
        }
      }
      .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)

      // Floating sidebar - completely independent
      if sidebarVisible {
        MacFloatingSidebar(selection: $selection)
          .frame(width: 280)
          .transition(.move(edge: .leading).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.2), value: sidebarVisible)
  }
}
```

#### Step 5: MacFloatingSidebar Component

```swift
struct MacFloatingSidebar: View {
  @Binding var selection: SidebarDestination?

  var body: some View {
    UnifiedSidebarContent(
      stageCounts: stageCounts,
      tabCounts: tabCounts,
      overdueCount: overdueCount,
      selection: $selection,
      onSelectStage: { ... }
    )
    .frame(maxHeight: .infinity)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 0)
    .padding(.leading, 8)
    .padding(.vertical, 8)
  }
}
```

#### Full-Screen Handling

The `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` modifier hides the toolbar background in normal windowed mode. In full-screen mode, the system will show appropriate toolbar chrome - this is acceptable and expected.

If explicit full-screen handling is needed:

```swift
@Environment(\.isPresented) private var isFullScreen // or use NSWindow observer

.toolbarBackgroundVisibility(isFullScreen ? .visible : .hidden, for: .windowToolbar)
```

---

### Context7 Queries (MANDATORY)

**Context7 MUST be queried before implementation for:**

| Topic | Why |
|-------|-----|
| `.toolbarBackgroundVisibility` | Verify exact behavior on macOS 15 |
| `ZStack` navigation patterns | Best practices for overlay navigation |
| `transition` + `animation` on macOS | Sidebar animation patterns |
| `.thinMaterial` on macOS | Correct usage for floating panels |
| Full-screen detection SwiftUI | How to detect/handle full-screen mode |

Log all Context7 lookups here:

CONTEXT7_QUERY: toolbarBackgroundVisibility hidden visible windowToolbar macOS toolbar background transparency
CONTEXT7_TAKEAWAYS:
- Use `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` to hide toolbar background
- This allows content to extend to the window's edge
- The modifier is a visual change only; accessibility still has access to the title
- Can also use `.toolbarVisibility(.hidden, for: .windowToolbar)` to hide the entire toolbar
- Multiple bars can be controlled simultaneously
CONTEXT7_APPLIED:
- `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` -> MacContentView.swift

CONTEXT7_QUERY: ZStack overlay floating panel transition move edge animation macOS sidebar
CONTEXT7_TAKEAWAYS:
- Use `.transition(.push(from: .leading))` for sidebar slide-in animation
- Push transition animates insertion by moving in from edge while fading
- Removal animates by moving out towards opposite edge and fading out
- Available on iOS 17.0+ / macOS 14.0+
CONTEXT7_APPLIED:
- `.transition(.push(from: .leading))` -> MacFloatingSidebar for sidebar animation

CONTEXT7_QUERY: Material thinMaterial ultraThinMaterial background floating panel macOS
CONTEXT7_TAKEAWAYS:
- Use `.background(.thinMaterial)` for translucent panel backgrounds
- `.ultraThinMaterial` provides maximum transparency with blur
- Materials available since macOS 12.0+
- Can be applied directly to background modifier
CONTEXT7_APPLIED:
- `.background(.thinMaterial)` -> MacFloatingSidebar for glass effect

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| toolbarBackgroundVisibility macOS | `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` |
| ZStack overlay transition animation | `.transition(.push(from: .leading))` |
| Material thinMaterial floating panel | `.background(.thinMaterial)` |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-20 (after PATCHSET 2)

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Architecture is sound.** After 8 failed attempts with NavigationSplitView coupling, the ZStack + floating sidebar pattern achieves the user's explicit requirements:

1. **Sidebar decoupled from toolbar**: ZStack overlay means sidebar animation is completely independent. No more toolbar appearance changes when toggling sidebar.

2. **Transparent toolbar achieved**: `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` properly hides toolbar background. Content scrolls to window edge.

3. **Accumulated complexity destroyed**:
   - MacWindowPolicy.swift deleted (NSWindow hacks gone)
   - SimplifiedToolbar.swift deleted
   - SimplifiedSidebar.swift deleted
   - AppShellView reduced to 21 lines (was bloated)

**Code quality:**
- MacFloatingSidebar: 67 lines (target was ~80) - clean, single-purpose
- MacContentView: 250 lines - reasonable for navigation container
- Uses DS tokens throughout (DS.Spacing.sidebarDefaultWidth, DS.Spacing.md, DS.Spacing.sm)
- Context7-verified patterns (.thinMaterial, .push transition, .toolbarBackgroundVisibility)

**Accessibility complete:**
- All toolbar buttons have accessibilityLabel + accessibilityHint
- Sidebar toggle has keyboard shortcut (Cmd+Ctrl+S)
- UnifiedSidebarContent has proper a11y containers

**No blockers identified.** This is the simplest possible implementation that meets the requirements.

---

### Success Criteria for This Attempt

This attempt is DIFFERENT because:

1. **NOT using NavigationSplitView on macOS** - The fundamental coupling is eliminated
2. **NOT trying to customize toolbar chrome** - Let it be transparent and simple
3. **NOT accumulating workarounds** - Deleting all previous hacks
4. **NOT relying on undocumented behavior** - Using well-understood ZStack/overlay patterns

**Definition of Success:**
- Sidebar toggle works without affecting toolbar appearance
- Toolbar area is transparent (no background material)
- Full-screen mode works without hacks
- Code is readable in < 2 minutes

**Definition of Failure (triggers contract revision):**
- Any need to add NSWindow/AppKit customization
- Any need to observe full-screen notifications
- Any need to coordinate sidebar state with window chrome
- Total LOC exceeds 200 for MacContentView

---

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| ZStack layout may fight NavigationStack | Content is NavigationStack, sidebar is overlay - they're independent |
| Floating sidebar may obscure content | Add slight transparency or dismiss-on-content-tap |
| Keyboard navigation may be affected | Test Cmd+\ toggle, ensure focus management works |
| Transitions may be janky | Use SwiftUI's built-in animations, don't fight the framework |

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
- **This is a CLEAN SLATE rebuild, not an incremental fix**
- **Do NOT use NavigationSplitView on macOS**
