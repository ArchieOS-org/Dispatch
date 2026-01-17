# Context7 Mandatory Usage (CRITICAL)

**Your training data is outdated. Context7 is the source of truth for all library documentation.**

## Core Principle

You were trained on documentation that is months or years old. APIs change, patterns evolve, and best practices get updated. **Context7 provides current, accurate documentation** that supersedes your training.

## Mandatory Behavior

Before writing ANY code that uses external libraries or frameworks, you MUST:

1. **Resolve the library ID**:
   ```
   mcp__context7__resolve-library-id
   - libraryName: "swift" (or relevant library)
   - query: "what you're trying to do"
   ```

2. **Query the documentation**:
   ```
   mcp__context7__query-docs
   - libraryId: "/swiftlang/swift" (from step 1)
   - query: "specific pattern or API question"
   ```

3. **Use the documented pattern**, not your training memory

## When to Use Context7

| Scenario | Action |
|----------|--------|
| Using SwiftUI views/modifiers | Query Context7 |
| Using Swift concurrency (async/await, actors) | Query Context7 |
| Using SwiftData/CoreData | Query Context7 |
| Using Supabase client | Query Context7 |
| Debugging unexpected behavior | Query Context7 FIRST |
| Implementing any framework pattern | Query Context7 |

## Pre-Resolved Library IDs (Common)

| Library | Context7 ID |
|---------|-------------|
| Swift | `/swiftlang/swift` |
| SwiftUI | `/websites/developer_apple_swiftui` |
| Supabase | Use `resolve-library-id` |

## Output Format

When using Context7, report what you consulted:

```
CONTEXT7 CONSULTED:
- Library: [name]
- Query: [what you asked]
- Pattern used: [brief summary]
```

## Enforcement

This rule is **MANDATORY** for all agents:
- **feature-owner**: Must use Context7 before implementing patterns
- **swift-debugger**: Must use Context7 before second fix attempt
- **ui-polish**: Must use Context7 for SwiftUI modifiers
- **dispatch-explorer**: Should use Context7 to understand framework patterns

## Why This Matters

1. **Your training is stale** - Swift 6, SwiftUI updates, Supabase v2 may differ from training
2. **Bugs from outdated patterns** - Using deprecated or incorrect APIs causes subtle bugs
3. **Time wasted debugging** - Wrong patterns lead to hours of debugging that Context7 prevents
4. **Framework-first principle** - Context7 shows how frameworks are *designed* to work

## Anti-Patterns (NEVER DO)

- Writing code from memory without checking Context7
- Assuming your training knowledge is current
- Skipping Context7 "to save time" (it costs more time debugging later)
- Ignoring Context7 results in favor of training memory

## Example Flow

```
Task: Implement MainActor isolation for a sync handler

1. mcp__context7__resolve-library-id(libraryName="swift", query="MainActor isolation patterns")
   → Returns: /swiftlang/swift

2. mcp__context7__query-docs(libraryId="/swiftlang/swift", query="MainActor class isolation async methods")
   → Returns: Current Swift 6 patterns for actor isolation

3. Implement using the documented pattern, NOT training memory
```

---

**Remember: Context7 is not optional. It's your primary source of truth.**
