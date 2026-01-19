## Interface Lock

**Feature**: HIG Menu & Sidebar Audit
**Created**: 2026-01-17
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
| 1 | Compiles + audit complete | dispatch-explorer, feature-owner |
| 2 | Fixes implemented, tests pass | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. All sidebar menu items meet Apple HIG touch/click target requirements (44pt minimum)
2. Menu item spacing, padding, and typography follow platform-specific HIG conventions (macOS vs iOS/iPadOS)
3. Sidebar width constraints and content alignment match Apple HIG standards

### Non-goals (prevents scope creep)

- No new navigation patterns or menu items
- No changes to menu functionality or behavior
- No design system token changes (DS.* values remain unchanged unless HIG-required)
- No changes to stage cards or non-navigation elements

### Compatibility Plan

- **Backward compatibility**: N/A (visual changes only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits, no data impact

---

### Scope: Files to Audit

**Primary Targets** (menu/sidebar):
- `Dispatch/Design/Shared/Components/SidebarMenuRow.swift` - Unified menu row (iOS/iPad/macOS)
- `Dispatch/Features/Menu/Views/Components/SidebarDestinationList.swift` - macOS sidebar list
- `Dispatch/Features/Menu/Views/Components/SidebarTabList.swift` - macOS sidebar tabs
- `Dispatch/Features/Menu/Views/Screens/MenuPageView.swift` - iPhone menu page
- `Dispatch/Foundation/Platform/macOS/ResizableSidebar.swift` - macOS sidebar container

**Secondary Targets** (commands/supporting):
- `Dispatch/App/State/DispatchCommands.swift` - macOS menu bar commands

### HIG Audit Focus Areas

| Area | HIG Requirement | Current State | Action |
|------|-----------------|---------------|--------|
| Touch targets | >= 44pt hit area | Needs verification | Audit |
| Menu item padding | Platform-specific | Using DS.Spacing tokens | Audit |
| Sidebar width | macOS: 200-320pt typical | 240pt preview, min constraints in ResizableSidebar | Audit |
| Typography hierarchy | Clear primary/secondary distinction | Using DS.Typography | Audit |
| Icon sizing | 16-20pt for sidebar icons | 16pt medium weight | Audit |
| List row height | ~44pt standard | Needs verification | Audit |
| Platform conventions | macOS: selection-based; iOS: tap-to-navigate | Correctly separated | Audit |

---

### Ownership

- **dispatch-explorer**: Initial codebase exploration, identify all menu/sidebar files, audit current implementation against HIG
- **feature-owner**: Implement minimal, focused HIG corrections
- **jobs-critic**: Design bar verification for HIG compliance
- **ui-polish**: Final refinements for HIG alignment
- **data-integrity**: Not needed

---

### Context7 Queries (Required)

The following Context7 queries MUST be performed during this audit:

| Agent | Library | Query Topic |
|-------|---------|-------------|
| dispatch-explorer | SwiftUI | "sidebar list row height and touch target size HIG requirements" |
| dispatch-explorer | SwiftUI | "NavigationSplitView sidebar width constraints macOS" |
| feature-owner | SwiftUI | "List listRowInsets padding for HIG compliant spacing" |
| feature-owner | SwiftUI | "SF Symbol icon sizing in sidebar navigation" |
| ui-polish | SwiftUI | "accessibility minimum touch target size SwiftUI" |

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (/websites/developer_apple_swiftui)

| Query | Pattern Used |
|-------|--------------|
| frame modifier minHeight in List rows touch target size | `.frame(minHeight:)` with CGFloat for minimum height constraint |
| #if os(iOS) platform conditional compilation | `#if os(iOS)` / `#endif` for platform-specific modifiers |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-17 (jobs-critic)

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The HIG correction is precisely executed:

1. **Minimal change** - 3 lines of platform-conditional code, single purpose
2. **Uses design system** - References `DS.Spacing.minTouchTarget` (44pt), not magic numbers
3. **Platform-appropriate** - iOS/iPadOS gets 44pt enforcement; macOS correctly defers to system List row height
4. **No visual change** - Only ensures minimum hit area, does not alter appearance
5. **Correct placement** - minHeight applied to Label frame before contentShape, ensuring proper tap area

This is exactly what Apple would ship: a focused, invisible correction that ensures accessibility compliance without disrupting platform conventions.

---

### Implementation Notes

**Context7 Recommendation**: Agents SHOULD use Context7 for:
- Apple HIG specifications for sidebar/menu patterns
- SwiftUI list row sizing and padding APIs
- Platform-specific (macOS vs iOS) navigation conventions
- Accessibility requirements for touch targets

**Key Design System Tokens** (reference from DESIGN_SYSTEM.md):
- `DS.Spacing.minTouchTarget` = 44pt (already HIG compliant)
- `DS.Spacing.lg` = 16pt (menu item padding)
- `DS.Typography.body` = 17pt (menu text)
- `DS.Spacing.sidebarMinWidth` (check ResizableSidebar)

**Current Implementation Observations**:
1. `SidebarMenuRow` uses `.font(.system(size: 16, weight: .medium))` for icons - HIG compliant
2. `SidebarMenuRow` uses `.contentShape(Rectangle())` for hit area - good
3. `MenuPageView` uses `.listRowInsets(EdgeInsets(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))` - verify HIG
4. macOS sidebar preview shows 240pt width - within typical range
5. macOS sidebar has min/max width constraints in `DS.Spacing.sidebarMinWidth` / `sidebarMaxWidth`

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
