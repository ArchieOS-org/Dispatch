## Interface Lock

**Feature**: AI Listing Description Generator
**Created**: 2026-01-15
**Status**: ARCHIVED (superseded by ai-listing-description.md)
**Lock Version**: v2 (Jobs cut)

---

## The Jobs Standard

> "Simplicity is the ultimate sophistication."

Two screens. One gesture. Magic.

**Screen 1:** Tell me about the property.
**Screen 2:** Here's your description.

Everything else is invisible.

---

### Contract

#### New/Changed Model Fields
- `DescriptionDraft` - Local-only model
  - `id: UUID`
  - `listingId: UUID?` - Auto-linked if launched from listing
  - `inputText: String`
  - `generatedDescription: String`
  - `tone: DescriptionTone?` - Selected refinement chip
  - `status: DraftStatus` - `.draft | .sent | .ready | .posted`
  - `pendingChange: String?` - Inline diff (replaces comparison screen)
  - `createdAt: Date`
  - `updatedAt: Date`

#### State Simplification (Jobs Cut)

**Internal enum (full complexity):**
```swift
enum DraftStatus {
  case draft        // Initial, editing
  case sent         // Awaiting approval (future)
  case ready        // Approved / ready to use
  case posted       // Marked as used
}
```

**UI shows only:**
| State | Chip | Color |
|-------|------|-------|
| Draft | subtle gray chip | `DS.Colors.Text.tertiary` |
| Sent | "Sent" | `DS.Colors.Status.inProgress` |
| Ready | "Ready" | `DS.Colors.Status.completed` |
| Posted | "Posted" | `DS.Colors.accent` |

**No visible state machine. No progress bar. No percent.**

#### DTO/API Changes
- **DEFERRED** - All heavily commented stubs

#### UI Events Emitted
- `onDescriptionGenerated`
- `onStatusChanged`

#### Migration Required
- **NO**

---

### Acceptance Criteria (3 max)

1. **One gesture magic**: Cmd+G → type → tap Generate → beautiful description appears with "writing..." animation (no percent, no progress bar).

2. **Two screens only**: Input screen and Output screen. Everything else is progressive disclosure (inline diffs, dropdown menus, sheets).

3. **Zero friction connection**: If launched from a listing, auto-link silently. Otherwise, "Attach to listing..." as subtle secondary action.

---

### Non-goals (prevents scope creep)

- **NO** comparison screen (inline diff only)
- **NO** visible workflow states beyond subtle chip
- **NO** "Awaiting Approval" mode in v1 (internal only)
- **NO** "Post to MLS" button (just "Mark as Posted" + "Copy")
- **NO** realtor feedback UI in v1
- **NO** photo analysis
- **NO** backend integration

---

## The Two Screens

### Screen 1: Input

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Tell me about this property...                         │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │  [Your property details here]                   │   │
│  │                                                 │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Tone: [Warm] [Luxury] [Family] [Concise] [...]  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [+ Photos]              [Attached: 123 Oak St ▼]      │
│                                                         │
│                    [ Generate ]                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Rules:**
- If launched from listing detail → "Attached: [Address]" appears pre-filled
- If launched from menu → "Attach to listing..." link (optional)
- Tone chips are optional, default = balanced
- Photos optional (future enhancement)

---

### Screen 2: Output

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Your description                           Draft ●     │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │  "Nestled in the heart of Rosedale, this       │   │
│  │   stunning 4-bedroom home offers the perfect   │   │
│  │   blend of classic charm and modern luxury..." │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [Copy]  [Edit]  [Regenerate ▼]                        │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [Warm] [Luxury] [Family] [Concise]    [More ▼]        │
│                                                         │
│              [ Mark as Ready ]                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Rules:**
- Status chip is subtle (top right), not a progress bar
- "Regenerate" dropdown: "Start over" / "Refine with current tone"
- Tone chips refine in-place (no navigation)
- "Mark as Ready" → chip becomes "Ready ✓"
- After Ready: "Copy for MLS" becomes primary action

---

### Inline Diff (Progressive Disclosure)

When refinement changes the description significantly:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  "Nestled in the heart of Rosedale, this       │   │
│  │   stunning 4-bedroom home offers [-the perfect │   │
│  │   blend of classic charm and modern luxury-]   │   │
│  │   [+an unparalleled lifestyle of refined       │   │
│  │   elegance and sophisticated comfort+]..."     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│           [Accept]  [Keep Original]                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**No separate comparison screen. Changes appear inline.**

---

### Generating State

No percent. No progress bar. Just:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│                     ✨ Writing...                       │
│                                                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Confident animation. 2-3 second delay. Done.

---

## File Structure (Simplified)

```
Dispatch/Features/DescriptionGenerator/
├── Models/
│   ├── DescriptionDraft.swift       # Local draft model
│   ├── DraftStatus.swift            # 4 states only
│   └── DescriptionTone.swift        # Tone enum
├── State/
│   ├── GeneratorState.swift         # @Observable
│   └── MockGeneratorService.swift   # Mocked AI
├── Views/
│   ├── DescriptionGeneratorView.swift  # 2-screen coordinator
│   ├── InputView.swift                 # Screen 1
│   ├── OutputView.swift                # Screen 2
│   ├── ToneChips.swift                 # Refinement chips
│   ├── InlineDiff.swift                # Accept/reject changes
│   └── GeneratingOverlay.swift         # "Writing..." state
└── (no Sheets/ folder - use system sheets)
```

---

## Ownership

- **feature-owner**: Full vertical slice
- **data-integrity**: NOT ASSIGNED
- **ui-polish**: Animation polish for "Writing..." state
- **integrator**: always

---

## Task Graph (DAG) - Simplified

```
PATCHSET 1: Models + State ─────────────────────────────────┐
│ • DraftStatus enum (4 states)                             │
│ • DescriptionTone enum                                    │
│ • DescriptionDraft model                                  │
│ • GeneratorState (@Observable)                            │
│ • AppCommand.openDescriptionGenerator                     │
│ • AppRoute.descriptionGenerator(listingId: UUID?)         │
│ ✓ Checkpoint: compile passes                              │
└───────────────────────────────────────────────────────────┘
                          │
                          ▼
PATCHSET 2: Two Screens ────────────────────────────────────┐
│ • DescriptionGeneratorView (coordinator)                  │
│ • InputView (text + tone chips + optional listing link)   │
│ • OutputView (description + copy + status chip)           │
│ • GeneratingOverlay ("Writing..." animation)              │
│ • Menu command: Cmd+G                                     │
│ • Auto-link listing if passed via route                   │
│ ✓ Checkpoint: builds iOS + macOS                          │
└───────────────────────────────────────────────────────────┘
                          │
                          ▼
PATCHSET 3: Refinement + Polish ────────────────────────────┐
│ • ToneChips component                                     │
│ • MockGeneratorService (realistic delay)                  │
│ • InlineDiff for significant changes                      │
│ • Status transitions (Draft → Ready → Posted)             │
│ • "Copy for MLS" action                                   │
│ ✓ Checkpoint: full workflow functional                    │
└───────────────────────────────────────────────────────────┘
                          │
                          ▼
PATCHSET 4: Integration + Cleanup ──────────────────────────┐
│ • "Attach to listing..." sheet (when not auto-linked)     │
│ • COMMENTED: Vercel API stubs                             │
│ • COMMENTED: Supabase persistence stubs                   │
│ • Unit tests for state machine                            │
│ • SwiftLint pass                                          │
│ ✓ Checkpoint: tests pass, lint clean                      │
└───────────────────────────────────────────────────────────┘
```

---

## Dangerous Ops

- [ ] None

---

## What We Cut (Phase 2+)

| Cut from v1 | Why | Phase |
|-------------|-----|-------|
| Comparison screen | Inline diff is simpler | - |
| Progress bar | "Writing..." is more confident | - |
| Realtor feedback UI | Approval is internal-only in v1 | 2 |
| "Post to MLS" button | Don't promise what we can't ship | 2 |
| Photo analysis | Scope creep | 2 |
| Session persistence | Local-only is faster to iterate | 2 |

---

## The Pitch (Final)

> Open the generator. Describe your property. Tap once.
>
> Beautiful listing copy appears.
>
> Copy it. Use it. Done.
>
> That's the whole product.

---

**Contract Status: ARCHIVED (superseded by ai-listing-description.md)**
