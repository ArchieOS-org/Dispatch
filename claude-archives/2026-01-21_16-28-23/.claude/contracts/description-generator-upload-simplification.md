## Interface Lock

**Feature**: Description Generator Upload Simplification
**Created**: 2026-01-15
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

### Contract
- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None (uses existing photo/document state)
- UI events emitted: New source picker action sheet on iOS/iPadOS
- Migration required: N

### Changes Summary
1. **Remove redundant header buttons**: Both PhotoUploadSection and DocumentUploadSection have "Add X" buttons in their headers that duplicate the empty state buttons. Remove the header buttons to simplify the UI.

2. **Add photo source picker (iOS/iPadOS only)**: When user taps "Select Photos", show a confirmation action sheet with two options:
   - "Photo Library" - opens PhotosPicker (current behavior)
   - "Files" - opens fileImporter (new option)

3. **Preserve cumulative upload behavior**: Ensure that selecting more photos/documents adds to the existing collection rather than replacing it. This is already working for documents; verify photos work the same way.

### Files to Modify
1. `Dispatch/Features/DescriptionGenerator/Views/Sections/PhotoUploadSection.swift`
   - Remove header "Add Photos" button (keep only empty state "Select Photos" button)
   - Add source picker (Photos vs Files) on iOS/iPadOS
   - Ensure cumulative uploads work correctly

2. `Dispatch/Features/DescriptionGenerator/Views/Sections/DocumentUploadSection.swift`
   - Remove header "Add Document" button (keep only empty state "Select Document" button)

### Acceptance Criteria (3 max)
1. Header "Add Photos" and "Add Document" buttons are removed; only empty state buttons remain
2. On iOS/iPadOS, tapping "Select Photos" shows source picker (Photo Library | Files); macOS continues using Files only
3. Uploading additional photos/documents appends to existing collection (cumulative, not replacement)

### Non-goals (prevents scope creep)
- No changes to document type categorization flow
- No changes to photo reordering or hero photo functionality
- No changes to the output/generation sections
- No drag-and-drop changes

### Compatibility Plan
- **Backward compatibility**: N/A - pure UI changes, no data changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert file changes

### Platform Behavior Matrix
| Platform | Photo Source Options | Document Source |
|----------|---------------------|-----------------|
| iOS | Photo Library OR Files (picker) | Files |
| iPadOS | Photo Library OR Files (picker) | Files |
| macOS | Files only (no change) | Files |

### Implementation Notes
- Use SwiftUI `.confirmationDialog()` for the source picker on iOS/iPadOS
- Keep the `PhotosPicker` and `fileImporter` logic separate for clarity
- Use Context7 to verify `confirmationDialog` best practices if needed

### Ownership
- **feature-owner**: PhotoUploadSection and DocumentUploadSection UI modifications
- **data-integrity**: Not needed (no schema/sync changes)

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-15 14:30

#### Checklist
- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes
The upload simplification achieves its goal cleanly:

**What works well:**
1. Removed redundant header buttons - now one path to add content per state (empty vs populated)
2. Photo grid uses subtle in-grid "Add" button that does not compete with photos
3. Document list uses discoverable "Add Document" button below content
4. iOS source picker (Photo Library | Files) via confirmationDialog is native and expected
5. macOS correctly skips picker and goes directly to Files
6. All components use DESIGN_SYSTEM.md tokens correctly
7. Touch targets meet 44pt minimum
8. Accessibility labels present on add buttons

**Design simplicity achieved:** User mental model is now "tap content area to add more" rather than hunting for buttons in headers. This is how Apple's Photos app works.

No blockers. Ship it.

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
