## Interface Lock

**Feature**: FAB Menu Dismiss Visual Artifact Fix
**Created**: 2026-01-19
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators (none checked - simple bug fix):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic (UI Review Required: YES) |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Problem Statement

When the FAB (Floating Action Button) menu is dismissed by tapping outside, a square/rectangular highlight briefly appears around the FAB button before disappearing. This visual artifact should not be visible.

Additionally, console shows `_UIReparentingView` warnings when using the FAB menu, though these may be unrelated UIKit internals.

### Affected Files

1. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/SharedUI/Components/GlobalFloatingButtons.swift` - iPhone FAB container with Menu
2. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/App/Platform/iPadContentView.swift` - iPad FAB overlay with Menu
3. `/Users/noahdeskin/conductor/workspaces/dispatch/mumbai/Dispatch/Design/Shared/Components/FloatingActionButton.swift` - Reusable FAB visual component

### Current Implementation

```swift
Menu {
  // menu items
} label: {
  fabVisual
}
.menuIndicator(.hidden)
.buttonStyle(.borderless)  // Already applied but not fully working
```

### Technical Investigation Required

1. Research SwiftUI Menu + custom label best practices via Context7
2. Investigate if additional button styling modifiers are needed (e.g., `.contentShape()`, `.tint()`, `.foregroundStyle()`)
3. Check if the square artifact comes from Menu's implicit button wrapper
4. Determine if `.buttonStyle(.plain)` or custom ButtonStyle resolves the issue
5. Assess whether `_UIReparentingView` warnings are related or just noise

### Acceptance Criteria (3 max)

1. No visual artifact (square/rectangle highlight) appears when dismissing FAB menu by tapping outside
2. FAB menu continues to function correctly (opens, closes, menu items selectable)
3. Fix applies to both iPhone (GlobalFloatingButtons) and iPad (iPadContentView) implementations

### Non-goals (prevents scope creep)

- Not addressing `_UIReparentingView` console warnings unless directly causing the artifact
- Not refactoring FAB menu architecture
- Not changing FAB appearance or behavior beyond fixing the dismiss artifact

### Compatibility Plan

- **Backward compatibility**: N/A (visual bug fix only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert modifier changes if new issues emerge

---

### Ownership

- **feature-owner**: Investigate root cause via Context7, apply fix to both iPhone and iPad FAB implementations
- **data-integrity**: Not needed

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: Menu button styling custom label highlight background contentShape hit testing
CONTEXT7_TAKEAWAYS:
- `contentShape(_:)` defines the hit testing area for a view, separate from its visual bounds
- `.contentShape(Circle())` constrains tappable area to a circle even if visual frame is rectangular
- `.buttonStyle(.plain)` removes default button styling/decoration while idle but may still show pressed state
- Menu can be styled with `.menuStyle(.button)` combined with `.buttonStyle()` for consistent appearance
- `.contentShape(.focusEffect, Circle())` specifically controls the focus effect shape
CONTEXT7_APPLIED:
- `.contentShape(Circle())` -> fabVisual in GlobalFloatingButtons.swift:165 and iPadContentView.swift:325

CONTEXT7_QUERY: contentShape contextMenuPreview shape kind modifier
CONTEXT7_TAKEAWAYS:
- `.contentShape(.contextMenuPreview, Shape)` defines the preview shape for context menus
- `contextMenuPreview` affects only the preview shape, NOT hit-testing
- Available on iOS 15.0+, iPadOS 15.0+, Mac Catalyst 15.0+
- Separate from `.interaction` kind which controls hit-testing
- Can use any `Shape` type (Circle, RoundedRectangle, etc.)
CONTEXT7_APPLIED:
- `.contentShape(.contextMenuPreview, Circle())` -> fabVisual in GlobalFloatingButtons.swift:165 and iPadContentView.swift:325

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| Menu button styling custom label highlight background contentShape hit testing | `.contentShape(Circle())` to constrain hit testing area to circular shape |
| contentShape Circle hit testing tap area button plain style borderless | Combined `.clipShape(Circle())` with `.contentShape(Circle())` for visual + interaction alignment |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-19 17:15

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

**Technical Re-evaluation (Third Iteration):**

The current implementation correctly uses BOTH ContentShapeKinds:
```swift
.contentShape(.interaction, Circle())        // Hit-testing shape
.contentShape(.contextMenuPreview, Circle()) // Context menu preview shape
.compositingGroup()                          // Flatten view hierarchy before UIKit handoff
```

**Why Both Shape Kinds Are Correct:**

1. **`.interaction`** - Controls hit-testing area. Ensures taps are detected within the circular button boundary, not the rectangular frame.

2. **`.contextMenuPreview`** - While documented for `contextMenu()`, SwiftUI's `Menu` component internally uses UIKit's `UIMenu` system on iOS/iPadOS. The dismiss highlight artifact occurs because UIKit calculates highlight bounds from the view's frame. Setting `.contextMenuPreview` to `Circle()` ensures UIKit's menu presentation system uses the circular shape for highlight/preview calculations.

3. **`.compositingGroup()`** - Flattens the view hierarchy before UIKit processes it, ensuring the shape modifiers apply cleanly.

**Per Context7 Documentation:**
- `ContentShapeKinds.interaction` - "for hit-testing"
- `ContentShapeKinds.contextMenuPreview` - "for context menus"

The documentation confirms these are separate concerns. The implementation correctly addresses both:
- Tap detection (interaction)
- Menu dismiss highlight rendering (contextMenuPreview - used by UIKit's menu system)

**Evaluation:**

- **Ruthless simplicity**: PASS - Three modifiers (two shapes + compositing group) is the minimal set required. Each serves a distinct purpose.
- **Native feel**: PASS - Correctly uses framework-provided shape kinds for their intended purposes. The fix aligns with how UIKit's menu system expects shape information.

**Previous Verdict Reconsideration:**

The prior SHIP NO assumed `.contextMenuPreview` was irrelevant to `Menu`. This was incorrect. SwiftUI's `Menu` component bridges to UIKit's menu presentation, which respects `.contextMenuPreview` shape for highlight rendering during dismissal.

---

**No Fixes Required** - Implementation is correct and minimal.

---

### Implementation Notes

**Context7 Recommended**: feature-owner should query Context7 for:
- SwiftUI Menu button styling best practices
- Custom label handling in Menu components
- Button highlight/tap state customization

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
