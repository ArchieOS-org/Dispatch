# Steve Jobs Design Bar (MANDATORY)

Design quality is not optional. Every UI change must meet this bar.

## Principles
- **Ruthless simplicity**: fewer controls, fewer words, fewer steps.
- **One clear primary action** per screen/state.
- **Strong hierarchy**: headline → primary action → secondary actions.
- **No clutter**: whitespace is a feature.
- **Native feel**: follow platform conventions (iOS/iPadOS/macOS) over novelty.

## Execution Rules
- Use **DESIGN_SYSTEM.md** components first. No random one-off UI.
- Use **SF Symbols** only. Keep symbol weight/style consistent.
- Prefer **system typography**; avoid custom fonts/styles unless already standardized.
- Touch targets ≥ **44pt**. Hit areas must be generous.
- Every screen must handle: **loading / empty / error** (no dead ends).
- Accessibility is required: **Dynamic Type, VoiceOver labels, contrast**, keyboard nav on macOS.
- Animations must be subtle + purposeful. No gimmicks.

## "Would Apple ship this?" Checklist
- [ ] Is there anything we can remove without losing meaning?
- [ ] Is the primary action obvious in <1 second?
- [ ] Does it look consistent with the rest of the app?
- [ ] Are all states handled cleanly?
- [ ] Does it feel calm, confident, and inevitable?

## Mechanical Enforcement

### Output Format (MANDATORY for all UI agents)
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

### Contract Enforcement
1. **jobs-critic** MUST write verdict to `.claude/contracts/<feature>.md`:
   - Field: `Jobs Critique: SHIP YES` or `Jobs Critique: SHIP NO`
   - This is MANDATORY, not optional

2. **integrator** MUST read contract at PATCHSET 4:
   - If `Jobs Critique: SHIP NO` → BLOCKED
   - If `Jobs Critique: PENDING` or missing → BLOCKED
   - Only `Jobs Critique: SHIP YES` allows DONE

3. **ui-polish** MUST report PASS/FAIL explicitly before completing
