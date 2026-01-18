## Interface Lock

**Feature**: Sign in with Apple
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: YES

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [x] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Rationale**:
- No schema changes: Supabase Auth handles Apple identity storage automatically
- Complex UI: Adding new login button to customer-facing LoginView requires design bar compliance
- Not high-risk: Authentication flow uses standard Apple/Supabase patterns
- Familiar area: Existing Google OAuth pattern in AuthManager provides clear template

### Patchset Plan

Based on checked indicators:

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles | feature-owner |
| 2 | Tests pass, criteria met | feature-owner, integrator |
| 2.5 | Design bar | jobs-critic, ui-polish |

---

### Contract

- New/changed model fields: None (Supabase Auth handles provider identity)
- DTO/API changes: None
- State/actions added:
  - `AuthManager.signInWithApple()` async method
  - `AppleSignInButton` SwiftUI view component
  - `ASAuthorizationControllerDelegate` conformance via coordinator
- Migration required: N

### Acceptance Criteria (3 max)

1. `SignInWithAppleButton` renders in LoginView below Google button, matching existing visual style (height, radius, shadow)
2. Tapping Apple button triggers `ASAuthorizationController` flow and successfully authenticates via Supabase `signInWithIdToken(provider: .apple, idToken:)`
3. Both Google and Apple sign-in continue to work end-to-end; error states display gracefully using existing error pattern

### Non-goals (prevents scope creep)

- No account linking (if user has both Google and Apple, they remain separate accounts)
- No "Sign in with Apple" for existing accounts migration
- No custom Apple button styling beyond matching existing Google button pattern
- No changes to sign-out flow (already works for any OAuth provider)

### Compatibility Plan

- **Backward compatibility**: N/A - additive feature, existing Google flow unchanged
- **Default when missing**: N/A
- **Rollback strategy**: Remove Apple button and `signInWithApple()` method; no data migration needed

---

### Ownership

- **feature-owner**: End-to-end implementation of Apple Sign-In (UI + AuthManager + ASAuthorizationController coordination)
- **data-integrity**: Not needed (no schema changes)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

CONTEXT7_QUERY: signInWithIdToken Apple OAuth provider authentication
CONTEXT7_TAKEAWAYS:
- Use `signInWithIdToken` endpoint with provider "apple", id_token, and nonce
- API expects JSON payload: `{id_token, nonce, provider: "apple"}`
- Apple Sign-In works out of box on iOS with "Sign in with Apple" capability enabled
- Supabase Swift uses `OpenIDConnectCredentials` type for ID token auth
CONTEXT7_APPLIED:
- OpenIDConnectCredentials with .apple provider -> AuthManager.swift:134

CONTEXT7_QUERY: SignInWithAppleButton AuthenticationServices ASAuthorizationAppleIDCredential
CONTEXT7_TAKEAWAYS:
- `SignInWithAppleButton` is native SwiftUI view from AuthenticationServicesSwiftUI
- Use `.signInWithAppleButtonStyle()` to customize appearance (.black, .white, etc.)
- Available iOS 14.0+, macOS 11.0+
- Use `authorizationController` environment value for authorization requests
CONTEXT7_APPLIED:
- SignInWithAppleButton with .signInWithAppleButtonStyle() -> LoginView.swift:107-115

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: YES
**Libraries Queried**: Supabase Swift, SwiftUI

| Query | Pattern Used |
|-------|--------------|
| signInWithIdToken Apple OAuth provider authentication | OpenIDConnectCredentials(provider: .apple, idToken:, nonce:) |
| SignInWithAppleButton AuthenticationServices ASAuthorizationAppleIDCredential | SignInWithAppleButton with .signInWithAppleButtonStyle() modifier |

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: SHIP YES
**Reviewed**: 2026-01-18 14:30

#### Checklist

- [x] Ruthless simplicity - nothing can be removed without losing meaning
- [x] One clear primary action per screen/state
- [x] Strong hierarchy - headline -> primary -> secondary
- [x] No clutter - whitespace is a feature
- [x] Native feel - follows platform conventions

#### Verdict Notes

The Sign in with Apple implementation meets the design bar. Key observations:

**Strengths:**
- Uses native `SignInWithAppleButton` from AuthenticationServices (Apple HIG compliant)
- Visual consistency with existing Google button: same height (50pt), shadow (`DS.Shadows.small`), corner radius (`DS.Spacing.radiusMedium`)
- Proper color scheme adaptation (white in dark mode, black in light mode)
- Touch target exceeds 44pt minimum
- Clean vertical hierarchy: brand identity -> action buttons -> footer
- Loading and error states handled correctly
- All DS tokens used consistently

**"Would Apple ship this?"**: Yes. The implementation uses Apple's own system-provided button with proper styling that matches the existing design language.

---

### Implementation Notes

#### Files to Modify

1. **`Dispatch/Features/Auth/Views/Screens/LoginView.swift`**
   - Add `AppleSignInButton` component below `GoogleSignInButton`
   - Style to match existing button pattern (50pt height, `DS.Spacing.radiusMedium`, `PressableButtonStyle`)

2. **`Dispatch/Foundation/Auth/AuthManager.swift`**
   - Add `signInWithApple()` async method
   - Implement `ASAuthorizationControllerDelegate` pattern via coordinator
   - Call Supabase `signInWithIdToken(provider: .apple, idToken:, nonce:)`
   - Note: Already imports `AuthenticationServices`

3. **`DispatchTests/AuthManagerTests.swift`**
   - Add mock for Apple sign-in flow
   - Test success case: credential received -> session created
   - Test failure case: user cancellation, auth error -> error displayed
   - Test existing Google tests still pass (regression check)

#### Apple Sign-In Implementation Pattern

```swift
// Coordinator pattern for ASAuthorizationController
// 1. Create nonce for security
// 2. Configure ASAuthorizationAppleIDRequest with nonce
// 3. Present ASAuthorizationController
// 4. On success: extract identityToken, call Supabase signInWithIdToken
// 5. Auth state changes stream handles session update
```

#### Key Considerations

- **Nonce**: Required for Supabase Apple auth - must be SHA256 hashed for request, raw for token exchange
- **Scopes**: Request `.email` scope; Supabase will store in user metadata
- **Platform**: AuthenticationServices works on iOS, iPadOS, and macOS (all target platforms)
- **SwiftUI Integration**: Use `SignInWithAppleButton` from AuthenticationServices or custom button with coordinator

---

**IMPORTANT**:
- If `UI Review Required: YES` -> integrator MUST verify `JOBS CRITIQUE: SHIP YES` before reporting DONE
- If `UI Review Required: NO` -> Jobs Critique section is not required; integrator skips this check
- If UI Review Required but Jobs Critique is missing/PENDING/SHIP NO -> integrator MUST reject DONE
- **Context7 Attestation**: integrator MUST verify `CONTEXT7 CONSULTED: YES` (or `N/A` for pure refactors) before reporting DONE
- If Context7 Attestation is missing or `NO` -> integrator MUST reject DONE
