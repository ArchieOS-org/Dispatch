# Framework-First Debugging

> **Version**: 2.0
> **Tier**: Mixed (see sections below)

**Don't fight the framework. Understand how it's designed to work, then use it correctly.**

## Core Principle [ADVISORY]

When fixing bugs or unexpected behavior, the correct approach is:
1. **Understand** the framework's intended pattern (via Context7 docs)
2. **Identify** where code deviates from that pattern
3. **Fix** by aligning with the framework, not by adding workarounds

## Red Flags: Stop and Research [GUIDELINE]

If ANY of these occur, STOP and use Context7 to research the correct pattern:

- [ ] Second fix attempt failed
- [ ] Adding `.id()` modifiers to force view updates
- [ ] Wrapping code in `DispatchQueue.main.async` without clear reason
- [ ] Using `withAnimation` to fix state propagation issues
- [ ] Creating manual `Binding(get:set:)` when direct binding exists
- [ ] Adding `@State` duplication to "sync" values
- [ ] Force-unwrapping optionals to "make it work"

**Two failed fixes = misunderstanding the root cause.** Research before attempting a third.

## Concrete Example: SwiftUI Bindings

**Bad** (fighting the framework):
```swift
// Manual binding with custom get/set - fragile, bypasses SwiftUI's change tracking
TextField("Search", text: Binding(
  get: { appState.lensState.audience },
  set: { appState.lensState.audience = $0 }
))
```

**Good** (using the framework correctly):
```swift
// Direct binding syntax - SwiftUI tracks changes automatically
TextField("Search", text: $appState.lensState.audience)
```

**Why the bad version fails**: Manual `Binding(get:set:)` breaks SwiftUI's dependency tracking. The framework can't detect that the view depends on `audience`, so it won't re-render when the value changes.

## Debugging Protocol [GUIDELINE]

### Step 1: Research First

Before ANY fix attempt:
```
1. mcp__context7__resolve-library-id with libraryName="swiftui" (or relevant framework)
2. mcp__context7__query-docs with query="[specific pattern you're using]"
```

### Step 2: Identify Deviation

Compare your code to the documented pattern:
- What does the framework expect?
- Where does our code differ?
- Why might someone have written it differently?

### Step 3: Fix by Alignment

The fix should make code MORE aligned with framework patterns, not less.

## Output Format [ENFORCED for debugging agents]

When debugging, agents MUST output:

```
FRAMEWORK-FIRST CHECK: [ALIGNED | DEVIATION FOUND]

Research:
- Consulted: [Context7 library/query]
- Expected pattern: [brief description]

Deviation (if found):
- Location: [file:line]
- Issue: [what deviates]
- Root cause: [why this causes the bug]
- Fix: [how to align with framework]
```

## Common SwiftUI Deviations

| Symptom | Common Deviation | Correct Pattern |
|---------|------------------|-----------------|
| View not updating | Manual `Binding(get:set:)` | Direct `$property` binding |
| Animation not working | Missing `withAnimation` wrapper | State change inside `withAnimation {}` |
| List not refreshing | Using `.id()` to force refresh | Proper `Identifiable` conformance |
| Navigation broken | Manual state management | `NavigationStack` with path binding |
| Keyboard not dismissing | Custom gesture hacks | `.scrollDismissesKeyboard()` modifier |

## Enforcement Tier Summary

| Aspect | Tier | Consequence |
|--------|------|-------------|
| Core principle | ADVISORY | Coaching, not blocking |
| Red flags / stop conditions | GUIDELINE | Strongly recommended |
| Research before second fix | GUIDELINE | Logged to contract |
| Output format | ENFORCED | Required for swift-debugger |

## What This Rule Does NOT Cover

- New feature implementation (covered by feature-owner protocol)
- Code style (covered by swiftlint/swiftformat)
- Architecture decisions (covered by modern-swift.md)

This rule applies specifically to debugging existing code and fixing bugs.

---

## Related Rules

- See `.claude/rules/context7-mandatory.md` for Context7 usage policy
- See `.claude/rules/modern-swift.md` for architecture principles
