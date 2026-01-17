# Context7 Usage [GUIDELINE - STRONGLY RECOMMENDED]

> **Version**: 2.0
> **Tier**: GUIDELINE (logged, not blocking)

**Your training data is outdated. Context7 is the source of truth for all library documentation.**

## Core Principle

You were trained on documentation that is months or years old. APIs change, patterns evolve, and best practices get updated. **Context7 provides current, accurate documentation** that supersedes your training.

## Behavior

Before writing ANY code that uses external libraries or frameworks, you SHOULD:

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

4. **Log to contract** (see Contract Logging below)

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

## Contract Logging [ENFORCED]

**Agents MUST log Context7 queries to the contract file.**

After using Context7, add to the contract's `Context7 Queries` section:

```markdown
### Context7 Queries
- [library]: [question asked] → [brief pattern/answer used]
- [library]: [question asked] → [brief pattern/answer used]
```

**Enforcement**: Integrator checks for presence of Context7 Queries section when contract indicates framework usage. Missing queries trigger a warning (not blocking) but are logged.

## Enforcement Tiers

| Aspect | Tier | Consequence |
|--------|------|-------------|
| Using Context7 before framework code | GUIDELINE | Strongly recommended, not blocking |
| Logging queries to contract | ENFORCED | Integrator checks, warns if missing |
| Following documented patterns | GUIDELINE | Evaluated by jobs-critic for UI |

## Agent Responsibilities

- **feature-owner**: Should use Context7 before implementing patterns; MUST log to contract
- **swift-debugger**: Should use Context7 before second fix attempt
- **ui-polish**: Should use Context7 for SwiftUI modifiers; MUST log to contract
- **dispatch-explorer**: May use Context7 to understand framework patterns

## Why This Matters

1. **Your training is stale** - Swift 6, SwiftUI updates, Supabase v2 may differ from training
2. **Bugs from outdated patterns** - Using deprecated or incorrect APIs causes subtle bugs
3. **Time wasted debugging** - Wrong patterns lead to hours of debugging that Context7 prevents
4. **Framework-first principle** - Context7 shows how frameworks are *designed* to work

## Anti-Patterns (AVOID)

- Writing code from memory without checking Context7
- Assuming your training knowledge is current
- Skipping Context7 "to save time" (it costs more time debugging later)
- Ignoring Context7 results in favor of training memory
- Forgetting to log queries to contract

## Example Flow

```
Task: Implement MainActor isolation for a sync handler

1. mcp__context7__resolve-library-id(libraryName="swift", query="MainActor isolation patterns")
   → Returns: /swiftlang/swift

2. mcp__context7__query-docs(libraryId="/swiftlang/swift", query="MainActor class isolation async methods")
   → Returns: Current Swift 6 patterns for actor isolation

3. Implement using the documented pattern, NOT training memory

4. Log to contract:
   ### Context7 Queries
   - Swift: MainActor class isolation async methods → Use @MainActor on class, nonisolated for sync-safe methods
```

---

**Remember: Context7 is strongly recommended but not blocking. What IS required: logging your queries to the contract.**
