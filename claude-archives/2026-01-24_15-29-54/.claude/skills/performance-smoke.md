# Performance Smoke Test

## Purpose
Catch obvious performance issues before they reach production - heavy views, unbounded fetches, main thread blocks.

## When to Run
- New screens with data loading
- Complex view hierarchies (nested stacks, heavy modifiers)
- Any Supabase query changes
- List views with many items

## Steps (Max 10)
1. Check for `@State`/`@StateObject` at wrong hierarchy level (causing over-rendering)
2. Verify heavy computations aren't in `body` (move to computed properties or cache)
3. Check Supabase queries have reasonable limits (no unbounded `.select()`)
4. Verify images are properly sized (no loading 4K images for thumbnails)
5. Check for `onAppear` that triggers network calls without debounce
6. Verify List/ForEach uses `id:` parameter for diffing efficiency
7. Check no synchronous file I/O on main thread
8. Verify async tasks are properly cancelled on view dismissal
9. Check for unnecessary view re-renders (use `Self._printChanges()` if debugging)
10. Verify no infinite loops possible in reactive chains (Combine/async)

## Output Format
```
PERF SMOKE: [PASS | FAIL]

Checked:
- [ ] State management: [status]
- [ ] Body complexity: [status]
- [ ] Query limits: [status]
- [ ] Image sizing: [status]
- [ ] Task cancellation: [status]

Concerns (if any):
- [file:line] [potential issue]
- Severity: [Low | Medium | High]
```
