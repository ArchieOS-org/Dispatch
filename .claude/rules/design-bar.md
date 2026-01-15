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
