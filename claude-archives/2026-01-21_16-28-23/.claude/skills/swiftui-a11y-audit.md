# SwiftUI Accessibility Audit

## Purpose
Verify all UI components meet Apple's accessibility standards for Dynamic Type, VoiceOver, and contrast.

## When to Run
- Any UI change that adds or modifies interactive elements
- New screens or views
- Changes to text, buttons, or navigation

## Steps (Max 10)
1. Verify all interactive elements have `.accessibilityLabel()` or meaningful text
2. Check `.accessibilityHint()` for non-obvious actions
3. Confirm no `.accessibilityHidden(true)` on important content
4. Verify text scales with Dynamic Type (use `.dynamicTypeSize` or system fonts)
5. Check color contrast meets WCAG AA (4.5:1 for text, 3:1 for large text)
6. Verify touch targets are >= 44pt
7. Confirm `.accessibilityAddTraits()` used correctly (`.isButton`, `.isHeader`, etc.)
8. Check focus order is logical (left-to-right, top-to-bottom)
9. Verify images have `.accessibilityLabel()` or are marked decorative
10. Test with VoiceOver mentally - does the reading order make sense?

## Output Format
```
A11Y AUDIT: [PASS | FAIL]

Checked:
- [ ] Labels: [status]
- [ ] Hints: [status]
- [ ] Dynamic Type: [status]
- [ ] Contrast: [status]
- [ ] Touch targets: [status]
- [ ] Focus order: [status]

Issues (if FAIL):
- [file:line] [issue description]
```
