## Interface Lock

**Feature**: Listing Generator Redesign
**Created**: 2026-01-15
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

### Contract
- New/changed model fields:
  - `ListingGeneratorDraft` (new SwiftData model): id, inputState, outputState, createdAt, updatedAt
  - Rename all `DescriptionGenerator*` types to `ListingGenerator*`
- DTO/API changes: None (client-side draft persistence only)
- State/actions added:
  - `ListingGeneratorState.saveDraft()` - persists current state as draft
  - `ListingGeneratorState.loadDraft(id:)` - restores from draft
  - `ListingGeneratorState.navigationPhase: .input | .output` - tracks current screen
- UI events emitted:
  - Navigation from input → output on generate
  - Navigation from output → input via back
  - Draft auto-save on significant changes
- Migration required: N (SwiftData handles schema automatically)

### Acceptance Criteria (3 max)
1. User can navigate from input screen to output screen and back without losing state
2. Every generation session is automatically saved as a draft accessible from listings screen
3. All references renamed from "Description Generator" to "Listing Generator"

### Non-goals (prevents scope creep)
- No Supabase sync for drafts in this iteration (Phase 2)
- No draft sharing between devices
- No draft versioning/history
- No changes to the actual AI generation logic

### Compatibility Plan
- **Backward compatibility**: N/A (rename only, no API changes)
- **Default when missing**: New SwiftData container created on first launch
- **Rollback strategy**: Delete SwiftData store file; rename files back

### Ownership
- **feature-owner**: Full vertical slice - rename, two-screen nav, draft model, listings integration
- **data-integrity**: Verify SwiftData model design (no Supabase changes needed)

### Structural Notes
- `DescriptionGeneratorState.swift` (675 lines) approaches God Object threshold - CONTAIN for now
- `DescriptionInputView.swift` and `DescriptionOutputView.swift` exist but unused - LEVERAGE for two-screen flow

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-15 14:30

#### Checklist
- [x] Ruthless simplicity - Two-screen flow is focused. Input collects data, Output presents results. Refinement appears only after selection (progressive disclosure). Nothing can be removed without losing meaning.
- [x] One clear primary action per screen/state - Input: "Generate Listing" button. Output: Select A or B card. Both are visually prominent and obvious.
- [x] Strong hierarchy - headline -> primary -> secondary - Sections use headline + caption pattern consistently. Typography hierarchy (headline -> body -> caption) is applied throughout.
- [x] No clutter - whitespace is a feature - Generous whitespace via DS.Spacing.sectionSpacing. Collapsible MLS field groups reduce visual noise. Suggestion chips hidden when user starts typing.
- [x] Native feel - follows platform conventions - Uses native controls (Picker, DisclosureGroup, PhotosPicker). Platform-adaptive layouts (split on iPad landscape/macOS, navigation on iPhone). SF Symbols throughout.

#### Verdict Notes
The Listing Generator redesign meets the design bar. Key strengths:

1. **Two-screen navigation** is clean and purposeful. Input screen focuses on data collection, output screen on result selection and refinement. State is preserved when navigating back.

2. **A/B comparison** implementation is excellent. Clear selection states (border, background tint, checkmark), version badges with tone descriptions, and appropriate VoiceOver announcements.

3. **MLS Fields section** handles complexity well through collapsible groups and Copy All functionality for workflow efficiency.

4. **Drafts integration** in ListingListView is unobtrusive - only appears when drafts exist, limited to 3 with "See all" affordance.

5. **Accessibility** is thorough - all interactive elements have labels and hints, state changes announced to VoiceOver.

All execution requirements met: DS components used throughout, touch targets >= 44pt, loading/empty/error states handled, animations are subtle and purposeful.

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
