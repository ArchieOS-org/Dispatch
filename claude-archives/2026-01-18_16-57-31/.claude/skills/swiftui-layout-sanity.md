# SwiftUI Layout Sanity Check

## Purpose
Verify SwiftUI layouts are robust, performant, and won't break on edge cases.

## When to Run
- Any new view or significant layout change
- After adding GeometryReader, ScrollView, or complex stacks
- When supporting multiple device sizes (iPhone, iPad, Mac)

## Steps (Max 10)
1. Verify no unbounded views (e.g., Text without `.lineLimit()` in constrained spaces)
2. Check for proper `.frame()` usage - avoid hardcoded sizes, prefer flexible layouts
3. Confirm ScrollView content doesn't exceed available memory (lazy loading for lists)
4. Verify GeometryReader isn't causing layout loops (use sparingly, prefer alignment guides)
5. Check safe area handling (`.ignoresSafeArea()` only when intentional)
6. Verify iPad/Mac layouts adapt properly (use `.horizontalSizeClass` or `ViewThatFits`)
7. Check orientation changes don't break layout
8. Verify keyboards don't obscure input fields
9. Confirm no negative padding/offset hacks that could break on different devices
10. Check List/ForEach uses stable identifiers (not array indices)

## Output Format
```
LAYOUT SANITY: [PASS | FAIL]

Checked:
- [ ] Unbounded views: [status]
- [ ] Frame usage: [status]
- [ ] Lazy loading: [status]
- [ ] Safe areas: [status]
- [ ] Multi-device: [status]
- [ ] Orientation: [status]

Issues (if FAIL):
- [file:line] [issue description]
```
