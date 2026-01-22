## Interface Lock

**Feature**: DIS-72: Listing Type Color Customization
**Created**: 2026-01-21
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [x] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 1.5 | Schema ready | data-integrity |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields:
  - `ListingTypeDefinition.colorHex: String?` - hex color string (e.g., "#4CAF50")
- DTO/API changes:
  - `ListingTypeDefinitionDTO` - add `colorHex` field (nullable, additive)
- State/actions added:
  - Color picker state in `ListingTypeDetailView`
  - Color application in `ListingTypePill` (read from definition if available, fallback to hardcoded)
- Migration required: Y (additive - new nullable column)

### Acceptance Criteria (3 max)

1. User can select a color for each listing type in Settings > Listing Types > [Type] detail view
2. Selected color persists to Supabase and syncs across devices
3. `ListingTypePill` displays the custom color when set, otherwise uses existing hardcoded defaults

### Non-goals (prevents scope creep)

- No color presets/palette UI - just use SwiftUI's native `ColorPicker`
- No bulk color editing across multiple types
- No color reset to default button (can just pick the original color)
- No changes to the `ListingType` enum - colors are on `ListingTypeDefinition` only

### Compatibility Plan

- **Backward compatibility**: Existing `ListingTypeDefinition` records have `colorHex = nil`, which means "use default"
- **Default when missing**: `ListingTypePill` falls back to existing hardcoded colors per `ListingType` case
- **Rollback strategy**: Column is nullable; if feature reverted, nil values trigger default behavior

---

### Technical Design

#### Color Storage Decision: Supabase (not UserDefaults)

**Rationale**:
- Colors are per-`ListingTypeDefinition`, which is a synced entity
- Must sync across devices/users on the same team
- `ListingTypeDefinition` already has sync infrastructure via `ListingTypeSyncHandler`
- UserDefaults is for local preferences, not shared team data

#### Model Changes

```swift
// ListingTypeDefinition.swift - add property
var colorHex: String?
```

#### DTO Changes

```swift
// ListingTypeDefinitionDTO.swift - add field
let colorHex: String?
```

#### UI Changes

1. **ListingTypeDetailView** - Add color picker section below type name
   - Use SwiftUI `ColorPicker` (native, accessible, platform-adaptive)
   - Bind to a computed Color property that converts to/from hex
   - Save triggers `markPending()` + `syncManager.requestSync()`

2. **ListingTypePill** - Update color computation
   - Accept optional `ListingTypeDefinition?` parameter
   - If definition has `colorHex`, use it
   - Otherwise fall back to existing hardcoded switch on `ListingType`

#### Color Conversion Utility

Create `Color+Hex.swift` extension:
- `Color(hex: String)` initializer
- `var hexString: String` computed property

---

### Ownership

- **feature-owner**: End-to-end implementation (model, DTO, UI, color utility)
- **data-integrity**: Supabase migration for `colorHex` column on `listing_type_definitions` table

---

### Files to Modify

| File | Changes |
|------|---------|
| `Dispatch/Features/Listings/Models/ListingTypeDefinition.swift` | Add `colorHex: String?` property |
| `Dispatch/Foundation/Networking/Supabase/DTOs/ListingTypeDefinitionDTO.swift` | Add `colorHex` field |
| `Dispatch/Features/Settings/Views/ListingTypeDetailView.swift` | Add ColorPicker section |
| `Dispatch/Features/Listings/Views/Components/ListingTypePill.swift` | Accept definition, use custom color |
| `Dispatch/Design/Extensions/Color+Hex.swift` (new) | Hex conversion utilities |

### Migration (data-integrity)

```sql
-- Additive migration: new nullable column
ALTER TABLE listing_type_definitions
ADD COLUMN color_hex TEXT;
```

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: SwiftUI Color initializer from hex string RGB color conversion
CONTEXT7_TAKEAWAYS:
- SwiftUI Color uses `init(_ colorSpace: RGBColorSpace, red: Double, green: Double, blue: Double, opacity: Double)`
- RGB component values are Doubles in range 0-1 for standard sRGB
- Extended sRGB allows values outside 0-1 range for wider gamut displays
- SwiftUI does NOT have a built-in hex string initializer - must be created as extension
CONTEXT7_APPLIED:
- `Color(red: Double, green: Double, blue: Double, opacity: Double)` initializer -> Color+Hex.swift:63

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: SwiftUI

| Query | Pattern Used |
|-------|--------------|
| SwiftUI Color initializer from hex string RGB color conversion | `Color(red:green:blue:opacity:)` with Double values 0-1 |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: PENDING
**Reviewed**: PENDING

#### Checklist

- [ ] Ruthless simplicity - nothing can be removed without losing meaning
- [ ] One clear primary action per screen/state
- [ ] Strong hierarchy - headline -> primary -> secondary
- [ ] No clutter - whitespace is a feature
- [ ] Native feel - follows platform conventions

#### Verdict Notes

(to be filled by jobs-critic)

---

### Implementation Notes

**Context7 Recommended For**:
- SwiftUI `ColorPicker` usage patterns and accessibility
- Color conversion (hex to Color) best practices in Swift
- Supabase Swift SDK patterns for additive migrations

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
