## Interface Lock

**Feature**: DIS-80: Move Three-Dot Menus Beside Page Titles
**Created**: 2026-01-22
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

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. Three-dot menu buttons appear beside (trailing edge of) inline titles on macOS and iPad (where `shouldUseInlineTitle` is true)
2. On iPhone (compact size class), three-dot menus remain in toolbar position (following HIG large title patterns)
3. All screens using StandardScreen with toolbar content render menus consistently across platforms

### Non-goals (prevents scope creep)

- No changes to menu content/actions (only positioning)
- No changes to iPhone large title behavior
- No new menu types or components
- No changes to OverflowMenu component internals

### Compatibility Plan

- **Backward compatibility**: N/A - UI-only change
- **Default when missing**: N/A
- **Rollback strategy**: Revert StandardScreen.swift changes

---

### Technical Analysis

#### Current State

**StandardScreen** (`Dispatch/App/Shell/StandardScreen.swift`):
- Accepts `@ToolbarContentBuilder toolbarContent` parameter (line 52)
- Toolbar content rendered via `.toolbar { toolbarContent() }` (lines 105-117)
- Inline title (`inlineTitleView`) rendered for macOS and iPad (lines 163-175)
- `shouldUseInlineTitle` determines when inline title is used (lines 140-146)

**Inline Title Layout** (current):
```swift
private var inlineTitleView: some View {
  Text(title)
    .font(DS.Typography.largeTitle)
    .foregroundStyle(DS.Colors.Text.primary)
    .frame(maxWidth: ..., alignment: .leading)
    .padding(.horizontal, horizontalPadding)
    .padding(.top, DS.Spacing.lg)
    .padding(.bottom, DS.Spacing.md)
}
```

#### Proposed Change

Modify StandardScreen to:
1. Accept optional `titleMenu` parameter for menu content
2. When `shouldUseInlineTitle` is true AND `titleMenu` is provided:
   - Render menu beside the title (trailing edge) in `inlineTitleView`
   - Remove menu from toolbar (or use `EmptyView`)
3. When `shouldUseInlineTitle` is false (iPhone):
   - Continue rendering menu in toolbar (current behavior)

#### Files to Modify

1. **`Dispatch/App/Shell/StandardScreen.swift`** - Core change
   - Add `titleMenu` parameter to initializers
   - Modify `inlineTitleView` to include HStack with title + menu
   - Conditionally suppress toolbar menu on macOS/iPad

2. **Screens using three-dot menus** (if any need explicit updates):
   - Current exploration shows most screens use empty toolbar or simple buttons
   - Preview in StandardScreen.swift shows `ellipsis.circle` example (line 343)

#### Design Pattern

```swift
// Proposed inlineTitleView structure
private var inlineTitleView: some View {
  HStack(alignment: .firstTextBaseline) {
    Text(title)
      .font(DS.Typography.largeTitle)
      .foregroundStyle(DS.Colors.Text.primary)

    Spacer()

    if shouldUseInlineTitle {
      titleMenu() // Render menu beside title on macOS/iPad
    }
  }
  .frame(maxWidth: layout == .fullBleed ? .infinity : DS.Spacing.Layout.maxContentWidth)
  .padding(.horizontal, horizontalPadding)
  .padding(.top, DS.Spacing.lg)
  .padding(.bottom, DS.Spacing.md)
}
```

---

### Ownership

- **feature-owner**: Modify StandardScreen to support menu-beside-title pattern; update any screens needing explicit migration
- **data-integrity**: Not needed
- **dispatch-explorer**: Initial codebase analysis (completed above)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: ViewBuilder generic parameter optional view EmptyView pattern for conditional content
CONTEXT7_TAKEAWAYS:
- Use `EmptyView` as the generic type when a view parameter is absent
- `buildIf` method handles optional views in result builders
- `buildBlock()` returns `EmptyView` for empty closures in `ViewBuilder`
CONTEXT7_APPLIED:
- EmptyView generic type -> StandardScreen.swift initializers (TitleMenu == EmptyView)

CONTEXT7_QUERY: ToolbarContentBuilder empty toolbar content EmptyView result builder
CONTEXT7_TAKEAWAYS:
- `ToolbarContentBuilder` requires at least one toolbar item
- No `buildBlock()` method for empty content like `ViewBuilder`
- Use `ToolbarItem` wrapping conditional content for cross-platform support
CONTEXT7_APPLIED:
- ToolbarItem wrapping conditional -> ListingDetailView.swift:23, PropertyDetailView.swift:23

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| ViewBuilder generic parameter optional view EmptyView | EmptyView as generic type for absent titleMenu |
| ToolbarContentBuilder empty toolbar content | ToolbarItem wrapping conditional content |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-22 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

Clean, platform-appropriate implementation.

**Strengths:**
- Minimal code: Single `titleMenu` ViewBuilder parameter, reuses existing `OverflowMenu` component
- Proper hierarchy: largeTitle (32pt bold) dominates, menu icon (20pt) is clearly secondary
- Correct platform behavior: macOS/iPad get inline menu beside title, iPhone compact retains toolbar per HIG
- Design system compliance: Uses DS.Typography, DS.Spacing.md, DS.Colors.Text.primary consistently
- A11y complete: 44pt touch targets, accessibilityLabel on OverflowMenu, Dynamic Type via @ScaledMetric

**Technical execution:**
- HStack with `firstTextBaseline` alignment ensures text/icon baseline alignment
- `hasTitleMenu` computed property cleanly handles EmptyView case
- Backwards compatible - screens without titleMenu continue working via generic default

No issues found. Would Apple ship this? Yes.

---

### Implementation Refinement (2026-01-22)

**Issue**: Menu was pushed to trailing edge due to `Spacer(minLength: 0)` in `inlineTitleView`.

**Fix**: Removed the Spacer so menu appears directly beside title text with only `DS.Spacing.md` gap.

**Before**:
```swift
if hasTitleMenu {
  Spacer(minLength: 0)  // Pushed menu to trailing edge
  titleMenu()
}
```

**After**:
```swift
if hasTitleMenu {
  titleMenu()  // Menu directly after title
}
```

---

### Implementation Notes

**Context7 Recommended For**:
- SwiftUI toolbar placement patterns (query `/websites/developer_apple_swiftui`)
- HIG guidelines for menu positioning in navigation views
- `@ToolbarContentBuilder` usage patterns

**Platform Considerations**:
- macOS: Menu beside title aligns with native app patterns (Finder, Safari)
- iPad: Should match macOS behavior for consistency
- iPhone: Keep toolbar menu to work with large title navigation bar

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
