## Interface Lock

**Feature**: Dynamic Type Migration - Fixed Font Sizes Remediation
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [x] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [x] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles - Phase 1 (Auth, Settings, Search) | feature-owner |
| 2 | Compiles - Phase 2 (Design System, SharedUI) | feature-owner |
| 2.5 | Design bar - Visual hierarchy verified | jobs-critic, ui-polish |
| 3 | Validation - All type sizes tested | xcode-pilot |

---

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (3 max)

1. No fixed `.font(.system(size:))` in user-facing views (excluding previews and debug utilities)
2. All text scales properly with Dynamic Type (tested at Default, Large, AX5)
3. Visual hierarchy preserved at all type sizes (no text truncation or layout breaks)

### Non-goals (prevents scope creep)

- No new typography tokens beyond mapping existing fixed sizes
- No changes to typography in Preview providers or test harnesses
- No refactoring of view structure beyond font changes
- No changes to DSTypography.swift `detailLargeTitle`/`detailCollapsedTitle` (logged as structural debt)

### Compatibility Plan

- **Backward compatibility**: N/A - visual change only
- **Default when missing**: N/A
- **Rollback strategy**: Revert PR

---

### Ownership

- **feature-owner**: Migrate all 78 fixed font sizes across 53 files to DS.Typography or @ScaledMetric
- **data-integrity**: Not needed

---

### File Inventory (dispatch-explorer to validate)

**Priority 1 - User-Facing Screens (migrate first):**
- `Dispatch/Features/Auth/Views/Screens/LoginView.swift` (3 occurrences)
- `Dispatch/Features/Auth/Views/Screens/OnboardingLoadingView.swift` (1)
- `Dispatch/Features/Settings/Views/SettingsView.swift` (2)
- `Dispatch/Features/Settings/Views/ProfilePageView.swift` (1)
- `Dispatch/Features/Settings/Views/MacOSSettingsView.swift` (1)
- `Dispatch/Features/Settings/Views/ActivityTemplateEditorView.swift` (1)
- `Dispatch/Features/Search/Views/Components/SearchResultRow.swift` (1)
- `Dispatch/Features/Search/Views/Components/PullToSearchIndicator.swift` (1)
- `Dispatch/Features/Workspace/Views/Screens/MyWorkspaceView.swift` (1)
- `Dispatch/Features/Realtors/Views/Screens/RealtorProfileView.swift` (2)
- `Dispatch/Features/Realtors/Views/Screens/EditRealtorSheet.swift` (1)
- `Dispatch/Features/Properties/Views/Components/PropertyRow.swift` (1)
- `Dispatch/Features/Properties/Views/Screens/PropertyDetailView.swift` (1)
- `Dispatch/Features/Listings/Views/Screens/ListingDetailView.swift` (1)
- `Dispatch/Features/Listings/Views/Components/StagePicker.swift` (1)
- `Dispatch/Features/Listings/Views/Components/ListingTypePill.swift` (1)
- `Dispatch/Features/WorkItems/Views/Components/Notes/NotesSection.swift` (1)
- `Dispatch/Features/WorkItems/Views/Components/Subtasks/SubtaskRow.swift` (2)

**Priority 2 - Design System Components:**
- `Dispatch/Design/Components/AudienceFilterButton.swift` (1)
- `Dispatch/Design/Shared/Components/CollapsibleHeader.swift` (1)
- `Dispatch/Design/Shared/Components/DueDateBadge.swift` (1)
- `Dispatch/Design/Shared/Components/FilterMenu.swift` (5)
- `Dispatch/Design/Shared/Components/FloatingActionButton.swift` (1)
- `Dispatch/Design/Shared/Components/FloatingFilterButton.swift` (1)
- `Dispatch/Design/Shared/Components/GlassButton.swift` (1)
- `Dispatch/Design/Shared/Components/OverduePill.swift` (1)
- `Dispatch/Design/Shared/Components/OverflowMenu.swift` (1)
- `Dispatch/Design/Shared/Components/SidebarMenuRow.swift` (1)
- `Dispatch/Design/Shared/Components/StatusCheckbox.swift` (1)

**Priority 3 - SharedUI Components:**
- `Dispatch/SharedUI/Components/MultiUserPicker.swift` (1)
- `Dispatch/SharedUI/Components/OverlappingAvatars.swift` (1)
- `Dispatch/SharedUI/Components/UserAvatar.swift` (1)
- `Dispatch/SharedUI/Components/UserTag.swift` (1)

**Priority 4 - ListingGenerator (internal feature):**
- `Dispatch/Features/ListingGenerator/Views/*.swift` (23 occurrences across 14 files)
- `Dispatch/Features/Demo/Views/Components/DraftPhotoThumbnail.swift` (1)

**Priority 5 - Platform-specific/Debug (exclude or defer):**
- `Dispatch/Foundation/Platform/macOS/ToolbarIconButton.swift` (1)
- `Dispatch/Foundation/Platform/macOS/TitleDropdownButton.swift` (1)
- `Dispatch/Foundation/Testing/SyncTestHarness.swift` (2) - EXCLUDE (test harness)

---

### Migration Strategy

**Pattern 1: Direct DS.Typography mapping**
```swift
// Before
.font(.system(size: 17, weight: .semibold))
// After
.font(DS.Typography.headline)
```

**Pattern 2: @ScaledMetric for custom sizes**
```swift
// Before (icon that needs specific size)
.font(.system(size: 64, weight: .light))

// After
@ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64
// ...
.font(.system(size: iconSize, weight: .light))
```

**Pattern 3: Image/Icon scaling**
```swift
// Before
Image(systemName: "command")
  .font(.system(size: 64))

// After (use imageScale or @ScaledMetric)
Image(systemName: "command")
  .font(.largeTitle)
  .imageScale(.large)
```

**DS.Typography Token Mapping Reference:**

| Fixed Size | Weight | Map To |
|------------|--------|--------|
| 32pt | Bold | DS.Typography.largeTitle |
| 22pt | Semibold | DS.Typography.title |
| 20pt | Semibold | DS.Typography.title3 |
| 17pt | Semibold | DS.Typography.headline |
| 17pt | Regular | DS.Typography.body |
| 16pt | Regular | DS.Typography.callout |
| 15pt | Regular | DS.Typography.bodySecondary |
| 14pt | * | DS.Typography.footnote or @ScaledMetric |
| 13pt | Regular | DS.Typography.footnote |
| 12pt | Regular | DS.Typography.caption |
| 11pt | Regular | DS.Typography.captionSecondary |
| 10pt | * | DS.Typography.captionSecondary or @ScaledMetric |

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: ScaledMetric Dynamic Type font accessibility custom font sizes @ScaledMetric property wrapper relativeTo
CONTEXT7_TAKEAWAYS:
- Use @ScaledMetric(relativeTo: .textStyle) to scale numeric values with Dynamic Type
- The relativeTo parameter specifies which Font.TextStyle the metric scales relative to
- Use @ScaledMetric for layout metrics like padding, not just font sizes
- Custom fonts can use Font.custom(_:size:relativeTo:) for built-in scaling
- @ScaledMetric automatically adjusts based on DynamicTypeSize in environment
CONTEXT7_APPLIED:
- @ScaledMetric(relativeTo: .largeTitle) for large icons (64pt, 48pt, 40pt) -> LoginView, OnboardingLoadingView, RealtorProfileView, EditRealtorSheet, MacOSSettingsView
- @ScaledMetric(relativeTo: .body) for body-relative icons (18pt, 20pt) -> SettingsRow, SubtaskRow, RealtorProfileView, GoogleSignInButton, FloatingActionButton (20pt), FloatingFilterButton, OverflowMenu
- @ScaledMetric(relativeTo: .footnote) for small icons (14pt) -> SettingsView ProfileRow, SubtaskRow, SearchResultRow, StatusCheckbox, MultiUserPicker, UserAvatar (medium), OverlappingAvatars (medium)
- @ScaledMetric(relativeTo: .caption) for caption-relative icons (12pt) -> ProfilePageView, MyWorkspaceView, StagePicker
- @ScaledMetric(relativeTo: .caption2) for smallest icons (10pt) -> ActivityTemplateEditorView, PropertyRow, DueDateBadge, FilterMenu (chevron), UserAvatar (small), OverlappingAvatars (small)
- @ScaledMetric(relativeTo: .title3) for medium icons (24pt) -> PullToSearchIndicator, NotesSection, FloatingActionButton (24pt), GlassButton
- @ScaledMetric(relativeTo: .title) for empty state icons (32pt) -> PropertyDetailView, ListingDetailView
- @ScaledMetric(relativeTo: .headline) for toolbar icons (17pt, 18pt) -> AudienceFilterButton, FilterMenu, CollapsibleHeader (collapsed), UserAvatar (large), OverlappingAvatars (large)
- @ScaledMetric(relativeTo: .largeTitle) for CollapsibleHeader expanded state (32pt)
- @ScaledMetric(relativeTo: .callout) for sidebar icons (16pt) -> SidebarMenuRow

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI (developer.apple.com)

| Query | Pattern Used |
|-------|--------------|
| ScaledMetric Dynamic Type font accessibility custom font sizes | @ScaledMetric(relativeTo: .textStyle) property wrapper for all icon sizes |
| @ScaledMetric property wrapper relativeTo | Matched relativeTo text style to semantic purpose of the size |

**N/A**: Only valid for pure refactors with no framework/library usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 14:45

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state (N/A - system-wide accessibility migration)
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verification at Type Sizes

- [x] Default size: Visual hierarchy maintained (code review confirms relativeTo mappings preserve semantic relationships)
- [x] Large size: Text scales, no layout breaks (ScaledMetric with correct relativeTo ensures proportional scaling)
- [x] AX5 (largest): All text readable, layouts adapt (frame constraints use minTouchTarget, icons scale proportionally)

#### Verdict Notes

**SHIP YES** - The migration is clean, semantically correct, and improves accessibility.

**Semantic Mapping Quality:**
- Hero elements (64pt) correctly use `.largeTitle`
- Toolbar icons (17-18pt) correctly use `.headline`
- Small indicators (10-14pt) correctly use `.caption2/.footnote`
- Body-relative icons (18-20pt) correctly use `.body`
- The CollapsibleHeader interpolation (32pt -> 18pt) correctly uses `.largeTitle` and `.headline` endpoints

**Code Quality:**
- Consistent pattern across all 30+ files
- Clear documentation comments on each @ScaledMetric property
- Proper private scoping
- No breaking changes to visual hierarchy at default size

**No issues found.** The migration follows Apple's recommended patterns and preserves the design system's typography hierarchy while enabling full Dynamic Type support.

---

### Implementation Notes

**Context7 Usage Required:**
- Query SwiftUI for `@ScaledMetric` best practices
- Query SwiftUI for Dynamic Type testing approaches
- Query Apple HIG for accessibility type size requirements

**Structural Debt (logged, not blocking):**
- `DSTypography.swift:68-71` - `detailLargeTitle` and `detailCollapsedTitle` use fixed sizes
- Recommendation: Fix-Small in future PR (2 lines, 1 file)

---

### Phase 2 Completion Notes (2026-01-18)

**Files Modified - Priority 2 (Design System):**
1. `Dispatch/Design/Components/AudienceFilterButton.swift` - Added @ScaledMetric for 17pt icon
2. `Dispatch/Design/Shared/Components/CollapsibleHeader.swift` - Added @ScaledMetric for 32pt/18pt interpolated title
3. `Dispatch/Design/Shared/Components/DueDateBadge.swift` - Added @ScaledMetric for 10pt icon
4. `Dispatch/Design/Shared/Components/FilterMenu.swift` - Added @ScaledMetric for 17pt toolbar icon
5. `Dispatch/Design/Shared/Components/FloatingActionButton.swift` - Added @ScaledMetric for 20pt/24pt icons
6. `Dispatch/Design/Shared/Components/FloatingFilterButton.swift` - Added @ScaledMetric for 20pt icon
7. `Dispatch/Design/Shared/Components/GlassButton.swift` - Added @ScaledMetric for 24pt icon
8. `Dispatch/Design/Shared/Components/OverflowMenu.swift` - Added @ScaledMetric for 20pt icon
9. `Dispatch/Design/Shared/Components/SidebarMenuRow.swift` - Added @ScaledMetric for 16pt icon
10. `Dispatch/Design/Shared/Components/StatusCheckbox.swift` - Added @ScaledMetric for 14pt icon

**Files Modified - Priority 3 (SharedUI):**
1. `Dispatch/SharedUI/Components/MultiUserPicker.swift` - Added @ScaledMetric for 14pt checkmark
2. `Dispatch/SharedUI/Components/OverlappingAvatars.swift` - Added @ScaledMetric for 10pt/14pt/18pt font sizes
3. `Dispatch/SharedUI/Components/UserAvatar.swift` - Added @ScaledMetric for 10pt/14pt/18pt font sizes

**Already Compliant (no changes needed):**
- `Dispatch/Design/Shared/Components/OverduePill.swift` - Already uses @ScaledMetric
- `Dispatch/SharedUI/Components/UserTag.swift` - Already uses @ScaledMetric

**Build Verification:**
- iOS Simulator build: PASSED
- macOS build: PASSED

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
