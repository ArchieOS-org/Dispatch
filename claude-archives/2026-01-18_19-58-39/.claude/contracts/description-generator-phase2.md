## Interface Lock

**Feature**: AI Listing Description Generator - Phase 2 Workspace
**Created**: 2025-01-15
**Status**: locked
**Lock Version**: v1

### Contract

- New/changed model fields:
  - `MLSFields` - All MLS copy-paste fields (propertyType, yearBuilt, sqft, etc.)
  - `UploadedPhoto` - Photo with sortOrder, isHero computed property
  - `UploadedDocument` - Document with DocumentType enum
  - `GeneratedOutput` - A/B version output container
  - `RefinementRequest` - Prompt-based refinement history
  - `PreferenceLog` - Training data preference capture (mock)
- DTO/API changes: None (all local mock)
- State/actions added:
  - `AppRoute.descriptionGenerator(listing: Listing?)` - New navigation route
  - `AppCommand.openDescriptionGenerator(listing:)` - Updated to navigate instead of sheet
  - Remove `SheetState.descriptionGenerator` - Replaced by navigation
  - `DescriptionGeneratorState` - Enhanced with photos, documents, dual output, refinement
- UI events emitted:
  - Copy individual MLS field to clipboard
  - Copy all MLS fields to clipboard
  - Select A/B preference (logged to mock training service)
  - Photo reorder via drag gesture
  - Refinement prompt submission
- Migration required: N (all local state, no persistence)

### New/Modified Files

```
REMOVE:
  SheetState.descriptionGenerator (from AppState.swift)
  Sheet presentation (from ContentView.swift)

MODIFY:
  Dispatch/App/State/AppRouter.swift           # Add AppRoute.descriptionGenerator
  Dispatch/App/State/AppState.swift            # Update command to navigate vs sheet
  Dispatch/App/State/AppDestinations.swift     # Add route handler
  Dispatch/Features/DescriptionGenerator/Models/DescriptionGeneratorState.swift  # Enhance

NEW:
  Dispatch/Features/DescriptionGenerator/
    Models/
      MLSFields.swift                 # MLS field model with copy support
      UploadedPhoto.swift             # Photo model with sorting
      UploadedDocument.swift          # Document model with type enum
      GeneratedOutput.swift           # A/B output container
      RefinementRequest.swift         # Refinement history model
    Services/
      MockAIService.swift             # Enhance: dual output, refinement
      MockTrainingDataService.swift   # Log A/B preferences (mock)
    Views/
      DescriptionGeneratorView.swift  # Main full-view workspace (replaces sheet)
      Sections/
        PhotoUploadSection.swift      # Photo grid + upload + reorder
        DocumentUploadSection.swift   # Document list + upload + type
        PropertyInputSection.swift    # Manual property details input
        OutputComparisonSection.swift # A/B side-by-side comparison
        MLSFieldsSection.swift        # Copy-paste field list
        RefinementSection.swift       # Prompt-based refinement
      Components/
        PhotoThumbnail.swift          # Draggable photo tile
        DocumentRow.swift             # Document list item
        MLSFieldRow.swift             # Field + copy button
        OutputCard.swift              # Single output version display
        VersionSelector.swift         # A/B toggle selector
```

### Acceptance Criteria (3 max)

1. Opens as full-view from Cmd+G (not modal); navigation back returns to previous view
2. Photo upload, drag-to-reorder, and document upload with type categorization work on iOS + macOS
3. Dual A/B output generation with selection logging and prompt-based refinement function correctly

### Non-goals (prevents scope creep)

- No actual Vercel AI backend integration (Phase 3)
- No Supabase persistence for photos/documents/outputs
- No real training data submission to backend
- No photo AI analysis (Phase 3)
- No document OCR/extraction (Phase 3)

### Compatibility Plan

- **Backward compatibility**: Phase 1 sheet removed; all navigation now uses full-view
- **Default when missing**: N/A (new feature enhancement)
- **Rollback strategy**: Revert navigation changes, restore SheetState.descriptionGenerator

### Ownership

- **feature-owner**: End-to-end vertical slice
  - Navigation integration (AppRoute, AppState, AppDestinations)
  - All new models (MLSFields, UploadedPhoto, UploadedDocument, GeneratedOutput, RefinementRequest)
  - All new views and sections
  - Mock service enhancements
  - Platform-adaptive layouts (iOS/iPad/macOS)
- **ui-polish**: DESIGN_SYSTEM.md compliance
  - Photo grid native feel (like Photos app)
  - A/B comparison clean layout
  - All states (loading/empty/error)
  - Accessibility (VoiceOver, Dynamic Type, keyboard nav on macOS)
  - Steve Jobs Design Bar compliance
- **integrator**: Verification
  - Build iOS + macOS each patchset
  - SwiftLint compliance
  - Done checklist verification
- **data-integrity**: NOT NEEDED (no schema changes, all local mock state)

### Design Notes

**Workspace Layout (Steve Jobs Bar)**:
- Clear visual flow: Input -> Generate -> Compare -> Select -> Refine
- Primary action obvious at each stage
- Platform-adaptive:
  - macOS: Three-column possible (input | output A | output B)
  - iPad landscape: Two-column adaptive
  - iOS/iPad portrait: Stacked sections with clear headers

**A/B Comparison UX**:
- Side-by-side on large screens, stacked on mobile
- Clear visual distinction between versions
- Selection highlights chosen version
- Preference logged immediately on selection

**Photo Grid UX**:
- Native feel like Photos app
- Drag-to-reorder with accessibility fallback (move up/down buttons)
- Hero photo (first) gets visual treatment
- Delete individual photos with confirmation

**MLS Fields UX**:
- Grouped by category (Property Details, Features, Descriptions, Marketing)
- Each field: label + editable value + copy button
- "Copy All" for bulk copy
- Inline editing for manual tweaks
