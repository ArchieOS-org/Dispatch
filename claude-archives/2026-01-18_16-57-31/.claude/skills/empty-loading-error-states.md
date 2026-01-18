# Empty/Loading/Error States Audit

## Purpose
Ensure every data-driven screen handles all possible states gracefully - no dead ends, no confusion.

## When to Run
- Any screen that loads data (from Supabase, network, or local storage)
- New list views or collection displays
- Search results or filtered content

## Steps (Max 10)
1. Identify all async data sources in the view
2. Verify **loading state** exists with appropriate indicator (ProgressView, skeleton, etc.)
3. Verify **empty state** exists with helpful message (not just blank screen)
4. Verify **error state** exists with:
   - Clear error message (user-friendly, not technical)
   - Retry action if applicable
   - Alternative path (back button, home, etc.)
5. Check loading indicator doesn't flash for instant loads (use delay if needed)
6. Verify empty state has actionable guidance (e.g., "Tap + to add your first item")
7. Check error states don't expose sensitive info (no stack traces, no internal IDs)
8. Verify pull-to-refresh works if applicable
9. Confirm skeleton/placeholder matches final content shape
10. Check transitions between states are smooth (no jarring layout shifts)

## Output Format
```
STATES AUDIT: [PASS | FAIL]

Screen: [screen name]
Data sources: [list]

Checked:
- [ ] Loading state: [status]
- [ ] Empty state: [status]
- [ ] Error state: [status]
- [ ] Retry action: [status]
- [ ] No dead ends: [status]

Issues (if FAIL):
- [missing state] [description]
```
