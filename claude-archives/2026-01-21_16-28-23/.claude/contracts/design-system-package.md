## Interface Lock

**Feature**: DesignSystem Swift Package
**Created**: 2026-01-16
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

### Contract

- New/changed model fields: None (package extracts existing tokens, no new models)
- DTO/API changes:
  - New `DSColor` semantic color tokens (replaces `DS.Colors`)
  - New `DSTypography` semantic text styles (replaces `DS.Typography`)
  - New `DSSpacing` spacing scale (replaces `DS.Spacing`)
  - New `DSRadius` corner radius scale (new extraction from `DS.Spacing.radius*`)
  - New `DSShadow` shadow styles (replaces `DS.Shadows`)
  - New `DSIcon` SF Symbol tokens (replaces `DS.Icons`)
- State/actions added: None
- UI events emitted: None
- Migration required: N

### Acceptance Criteria (3 max)

1. DesignSystem package at `/Packages/DesignSystem` compiles standalone with `swift build`
2. Dispatch app builds on iOS and macOS using DesignSystem as local package dependency
3. All existing views render identically after refactor (no visual regressions)

### Non-goals (prevents scope creep)

- No moving domain-specific components (e.g., `StageCardsGrid`, `ListingRow`) to DesignSystem
- No moving business logic or domain types to DesignSystem
- No creating SharedUI package in this contract (future scope)
- No Supabase or backend imports in DesignSystem
- No new visual designs or style changes
- No breaking existing `DS.*` namespace references in app (provide backward compat)

### Compatibility Plan

- **Backward compatibility**: Keep `DS` namespace as typealias/re-export from DesignSystem during transition
- **Default when missing**: N/A (no new fields)
- **Rollback strategy**: Remove DesignSystem package reference, restore original Design/ folder structure

### Ownership

- **feature-owner**: Full vertical slice - package creation, token migration, app refactor
- **data-integrity**: Not needed (no schema changes)

### Implementation Notes

**Use Context7 for**:
- Swift Package Manager best practices
- SwiftUI design system patterns

**Package Structure**:
```
/Packages/DesignSystem/
  Package.swift
  Sources/DesignSystem/
    DesignSystem.swift              # Main DS namespace export
    Tokens/
      DSColor.swift                 # Semantic colors (Background, Text, Status, etc.)
      DSTypography.swift            # Font styles with Dynamic Type
      DSSpacing.swift               # 4pt grid spacing scale
      DSRadius.swift                # Corner radius tokens
      DSShadow.swift                # Shadow/elevation styles
      DSIcon.swift                  # SF Symbol tokens
    Components/
      DSPill.swift                  # Generic pill/badge (from Pill.swift)
      DSButton.swift                # Button variants (from FloatingActionButton)
      DSCheckbox.swift              # Checkbox component (from StatusCheckbox)
      DSSectionHeader.swift         # Section header (from SectionHeader)
      DSProgressCircle.swift        # Progress indicator (from ProgressCircle)
      DSDivider.swift               # Styled divider
      DSListRow.swift               # Standard list row shell
    States/
      DSLoadingView.swift           # Loading spinner/skeleton
      DSEmptyStateView.swift        # Empty state with icon + message
      DSErrorBanner.swift           # Error display banner
    Helpers/
      ViewModifiers.swift           # dsShadow, hideDisclosure, etc.
      Extensions.swift              # View extensions
    Effects/
      GlassEffect.swift             # iOS 26+ glass effect
```

**Key Design Decisions**:
1. **Pure UI package** - NO business logic, NO domain types, NO Supabase imports
2. **Preserve DS namespace** - Components remain accessible as `DS.Colors`, `DS.Typography`, etc.
3. **Platform target**: iOS 18+ / macOS 15+ (aligned with app requirements)
4. **Dynamic Type support** - All typography tokens support accessibility scaling
5. **Dark mode ready** - All colors adapt automatically

**Components to Extract (domain-agnostic)**:
| Current Location | Target | Notes |
|-----------------|--------|-------|
| `Design/DesignSystem.swift` | `DesignSystem.swift` | Main namespace |
| `Design/ColorSystem.swift` | `Tokens/DSColor.swift` | Split into semantic groups |
| `Design/Typography.swift` | `Tokens/DSTypography.swift` | Keep Dynamic Type support |
| `Design/Spacing.swift` | `Tokens/DSSpacing.swift` + `DSRadius.swift` | Split radius into own file |
| `Design/Shadows.swift` | `Tokens/DSShadow.swift` | Keep view modifier |
| `Design/IconSystem.swift` | `Tokens/DSIcon.swift` | All SF Symbol tokens |
| `Design/Shared/Components/Pill.swift` | `Components/DSPill.swift` | Generic, no domain deps |
| `Design/Shared/Components/StatusCheckbox.swift` | `Components/DSCheckbox.swift` | Generic toggle |
| `Design/Shared/Components/FloatingActionButton.swift` | `Components/DSButton.swift` | Primary FAB |
| `Design/Shared/Components/SectionHeader.swift` | `Components/DSSectionHeader.swift` | Generic header |
| `Design/Shared/Components/ProgressCircle.swift` | `Components/DSProgressCircle.swift` | Generic progress |
| `Design/Effects/GlassEffect.swift` | `Effects/GlassEffect.swift` | iOS 26+ effect |
| `Design/ViewModifiers/*.swift` | `Helpers/ViewModifiers.swift` | Consolidated |

**Components to KEEP in App (domain-specific)**:
- `AudienceFilterButton.swift` - Uses `AudienceLens` domain type
- `DatePill.swift`, `DueDateBadge.swift`, `OverduePill.swift` - Date formatting logic
- `DateSectionHeader.swift` - Uses `DateSection` domain type
- `RealtorPill.swift` - Uses `Realtor` domain type
- `ListRowLink.swift` - Navigation-specific
- `SidebarMenuRow.swift` - App navigation structure
- `OverflowMenu.swift` - Domain-specific actions
- `CollapsibleHeader.swift` - Complex app-specific behavior
- `StandardGroupedList.swift`, `StandardList.swift` - App layout patterns
- `SegmentedFilterBar.swift` - Domain filter options

**Files to Modify in App**:
- `Dispatch.xcodeproj/project.pbxproj` - Add local package reference
- All files importing `DS.*` tokens - Update imports to `import DesignSystem`
- `Design/` folder - Remove migrated files, keep domain-specific components
- `SharedUI/Components/DomainDesignBridge.swift` - Update imports

**Patchset Plan**:
1. **PATCHSET 1**: Create package structure + migrate tokens (DSColor, DSTypography, DSSpacing, DSRadius, DSShadow, DSIcon)
2. **PATCHSET 2**: Migrate generic components (DSPill, DSCheckbox, DSButton, DSSectionHeader, DSProgressCircle)
3. **PATCHSET 3**: Migrate effects + helpers, wire app to use package
4. **PATCHSET 4**: Cleanup, verify builds, run tests

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist
N/A - No UI changes (refactor only, visual parity required)

#### Verdict Notes
No UI review required for this infrastructure refactor. All views must render identically post-migration.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
