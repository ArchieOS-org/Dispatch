# Modern Swift Simplicity

> **Version**: 2.0
> **Tier**: ADVISORY (trackable, not blocking)

Inspired by proven Swift project conventions. Less abstraction, more clarity.

## Core Principles

### 1. No ViewModel-per-View by Default
- Views can hold `@State` directly for local UI state
- Extract to separate type ONLY when:
  - State is shared across multiple views
  - Complex async logic requires testability
  - Business logic exceeds 50 lines
- **Violation**: Creating `FooViewModel` for a view that only needs 3 `@State` properties

### 2. Prefer Clarity Over Architecture Purity
- Code should be understandable by reading top-to-bottom
- Avoid indirection layers that "might be useful someday"
- If you need a comment explaining why the abstraction exists, you probably don't need it
- **Test**: Can a new developer understand this file in <2 minutes?

### 3. Feature-Local Organization
- Group by feature, not by type
- Bad: `ViewModels/`, `Services/`, `Models/` folders with 50 files each
- Good: `Features/Listings/`, `Features/Profile/` with all related code together
- Exception: Truly shared infrastructure (networking, auth) can be centralized

### 4. No God Objects
- If a type exceeds 500 lines or has >10 public methods, it's suspect
- If encountered:
  - **Fix Small threshold applies?** → Split it (≤2 files, ≤30 lines changed)
  - **Otherwise** → Contain changes and log to `.claude/debt/STRUCTURAL_DEBT.md`

### 5. Explicit Over Implicit
- Avoid magic strings, stringly-typed APIs
- Prefer enums over string constants
- Prefer explicit dependency injection over singletons/globals
- Exception: SwiftUI environment values are acceptable

## Enforcement

This rule is **advisory but trackable**:
- Agents MUST flag violations in their output
- Violations do NOT block builds (unlike lint errors)
- Repeated violations in same area → escalate to structural debt

## Output Format (when flagging violations)

```
MODERN SWIFT: [CLEAN | FLAGGED]

Flags (if any):
- [file:line] [violation type]: [brief description]
- Recommendation: [contain | fix-small | refactor-later]
```

## What This Rule Does NOT Cover

- Formatting (handled by swiftformat/swiftlint)
- Naming conventions (handled by swiftlint)
- API design (case-by-case review)

If it can be linted, it's not this rule's job.
