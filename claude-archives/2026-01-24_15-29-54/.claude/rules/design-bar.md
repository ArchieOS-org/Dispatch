# Steve Jobs Design Bar

> **Version**: 2.0
> **Tier**: Mixed (see sections below)

Design quality is not optional. Every UI change must meet this bar.

## Principles [ADVISORY]

These are guiding principles, not pass/fail gates:

- **Ruthless simplicity**: fewer controls, fewer words, fewer steps.
- **One clear primary action** per screen/state.
- **Strong hierarchy**: headline → primary action → secondary actions.
- **No clutter**: whitespace is a feature.
- **Native feel**: follow platform conventions (iOS/iPadOS/macOS) over novelty.

## Execution Rules [GUIDELINE]

Strongly recommended practices:

- Use **DESIGN_SYSTEM.md** components first. No random one-off UI.
- Use **SF Symbols** only. Keep symbol weight/style consistent.
- Prefer **system typography**; avoid custom fonts/styles unless already standardized.
- Touch targets ≥ **44pt**. Hit areas must be generous.
- Every screen must handle: **loading / empty / error** (no dead ends).
- Accessibility is required: **Dynamic Type, VoiceOver labels, contrast**, keyboard nav on macOS.
- Animations must be subtle + purposeful. No gimmicks.

## "Would Apple Ship This?" Checklist [ADVISORY]

Use this for self-evaluation:

- [ ] Is there anything we can remove without losing meaning?
- [ ] Is the primary action obvious in <1 second?
- [ ] Does it look consistent with the rest of the app?
- [ ] Are all states handled cleanly?
- [ ] Does it feel calm, confident, and inevitable?

## Mechanical Enforcement [ENFORCED]

### Output Format (Required for UI agents)

All agents reviewing UI must output:

```
DESIGN BAR: [PASS | FAIL]
- Ruthless simplicity: [✓/✗]
- One clear primary action: [✓/✗]
- Strong hierarchy: [✓/✗]
- No clutter: [✓/✗]
- Native feel: [✓/✗]

Failures (if any):
- [specific issue]
```

### Contract Enforcement [ENFORCED - BLOCKING]

1. **jobs-critic** MUST write verdict to `.claude/contracts/<feature>.md`:
   - Field: `JOBS CRITIQUE: SHIP YES` or `JOBS CRITIQUE: SHIP NO` (exact format)
   - This is MANDATORY when `UI Review Required: YES`

2. **integrator** MUST read contract at final patchset:
   - If `UI Review Required: NO` → skip Jobs Critique check, report `N/A`
   - If `UI Review Required: YES`:
     - If `JOBS CRITIQUE: SHIP NO` → **BLOCKED**
     - If `JOBS CRITIQUE: PENDING` or missing → **BLOCKED**
     - Only `JOBS CRITIQUE: SHIP YES` allows DONE

3. **ui-polish** MUST report `DESIGN BAR: PASS` or `DESIGN BAR: FAIL` explicitly before completing

## Enforcement Tier Summary

| Aspect | Tier | Consequence |
|--------|------|-------------|
| Design principles | ADVISORY | Coaching, not blocking |
| Execution rules | GUIDELINE | jobs-critic evaluates, subjective |
| Output format | ENFORCED | Required for UI agents |
| Jobs Critique verdict | ENFORCED | Blocks DONE if violated |
| Contract field presence | ENFORCED | Integrator rejects if missing |

## When Jobs-Critic Runs [CONDITIONAL]

jobs-critic is **only invoked when**:
- `UI Review Required: YES` in contract
- Customer-facing UI changes
- Hierarchy/layout changes
- Primary interaction changes

jobs-critic is **skipped when**:
- Backend-only changes
- Non-visual refactoring
- Bug fixes with no UI impact
- `UI Review Required: NO` in contract

---

**The Jobs Test**: "Would Apple ship this?" is a philosophy, not a checklist. The checklist helps operationalize it, but judgment matters.
