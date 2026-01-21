## Interface Lock

**Feature**: User Profile Management
**Created**: 2026-01-15
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

### Contract
- New/changed model fields: None (using existing User model with userType)
- DTO/API changes: None (RLS already allows user self-update)
- State/actions added:
  - `updateUserType(newType: UserType)` - Updates current user's type in Supabase
  - `signOut()` - Already exists in AuthManager, needs UI wiring
- UI events emitted:
  - Profile section added to Settings
  - User type confirmation dialog
  - Logout confirmation
- Migration required: N

### Acceptance Criteria (3 max)
1. User can view their profile (name, email, avatar, current type) from Settings
2. User can change their user type with a confirmation step before saving
3. User can log out with confirmation, returning to sign-in screen

### Non-goals (prevents scope creep)
- No profile photo editing (uses Google avatar)
- No name/email editing (comes from Google OAuth)
- No admin-only type restrictions (any user can change their own type)
- No user type history/audit trail

### Compatibility Plan
- **Backward compatibility**: N/A - no DTO changes
- **Default when missing**: N/A
- **Rollback strategy**: Revert commits; no data migration needed

### Ownership
- **feature-owner**: Full implementation - Profile UI, navigation, logout wiring, type change with confirmation
- **data-integrity**: Not needed (RLS policy already supports user self-update)

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-15 14:30

#### Checklist
- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline → primary → secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes
The profile section is clean, focused, and native-feeling. Three elements (header, role picker, sign out) map directly to the three acceptance criteria with no excess.

Strengths:
- UserAvatar at 44pt creates strong visual anchor
- Confirmation dialogs prevent accidents without adding friction
- Role picker uses native Menu pattern with chevron affordance
- Destructive styling on sign out makes it appropriately cautionary
- All DS tokens used correctly (typography, colors, spacing, icons)
- Accessibility labels present on all interactive elements
- Loading/error states handled gracefully

"Would Apple ship this?" - Yes. This is a standard, well-executed settings profile section.

---

**IMPORTANT**:
- If `UI Review Required: YES` → integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` → Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO → integrator MUST reject DONE
