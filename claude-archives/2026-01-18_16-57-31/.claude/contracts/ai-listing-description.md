## Interface Lock

**Feature**: AI Listing Description Generator
**Created**: 2025-01-15
**Status**: locked
**Lock Version**: v1

### Contract

- New/changed model fields: None (Phase 1 is read-only)
- DTO/API changes: None (mocked AI service)
- State/actions added:
  - `AppCommand.openDescriptionGenerator(listing: Listing?)`
  - `AppState.SheetState.descriptionGenerator(listing: Listing?)`
  - `DescriptionGeneratorState` (local @Observable)
- UI events emitted:
  - Copy to clipboard
  - "Send to Agent" (mocked)
- Migration required: N

### New Files

```
Dispatch/Features/DescriptionGenerator/
  Models/
    DescriptionStatus.swift       # Draft|Sent|Ready|Posted enum
    DescriptionGeneratorState.swift  # @Observable local state
  Services/
    MockAIService.swift           # Stubbed AI with realistic delays
  Views/
    DescriptionGeneratorSheet.swift   # Main sheet container
    DescriptionInputView.swift        # Screen 1: listing picker OR manual input
    DescriptionOutputView.swift       # Screen 2: result + status + copy
    Components/
      DescriptionStatusChip.swift     # Subtle status badge
      ListingPickerRow.swift          # Listing selection row
```

### Acceptance Criteria (3 max)

1. User can generate description from existing listing selection OR manual property input
2. Output displays status chip (Draft/Sent/Ready/Posted) and Copy action
3. Builds on iOS + macOS without errors

### Non-goals (prevents scope creep)

- No actual Vercel AI backend integration (Phase 2)
- No Supabase writes/migrations (Phase 2)
- No realtor chat integration
- No iterative AI refinement with side-by-side comparison
- No photo upload/analysis (Phase 2)

### Compatibility Plan

- **Backward compatibility**: N/A (new feature)
- **Default when missing**: N/A
- **Rollback strategy**: Remove feature flag / delete files

### Ownership

- **feature-owner**: End-to-end vertical slice - models, state, views, mock service, menu command integration
- **ui-polish**: DESIGN_SYSTEM.md compliance, platform-specific layouts, empty/loading/error states
- **integrator**: Build verification iOS + macOS, SwiftLint
- **data-integrity**: NOT NEEDED (Phase 1 is read-only, no schema changes)

### Design Notes

**Two-Screen Flow (Steve Jobs Bar)**:
1. **Input Screen**: Segmented picker (Existing Listing | Manual Entry) + Generate button
2. **Output Screen**: Generated text + status chip + Copy + "Send to Agent" (mocked)

**Menu Integration**:
- macOS: Edit menu, Cmd+G shortcut
- iOS: Accessible from Listing detail view toolbar

**Status Chip Semantics**:
- `Draft`: Just generated, not sent
- `Sent`: Sent to agent for approval (mocked transition)
- `Ready`: Agent approved (auto-transition after delay in mock)
- `Posted`: User confirmed posting (final state)
