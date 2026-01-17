# Style Enforcement Policy

> **Version**: 2.0
> **Tier**: ENFORCED (blocks DONE if lint fails)

## Core Principle

**If it can't be enforced by lint/format/build/test, it's a preference, not a rule.**

We follow the Airbnb philosophy: rules must be mechanically enforceable.

## Lintable Rules Only (Airbnb Tenet)

A rule is only a rule if it can be checked by a machine:
- SwiftLint can flag it → it's a rule
- SwiftFormat can fix it → it's a rule
- Compiler rejects it → it's a rule
- Human must judge it → it's a **guideline**, not a rule

**Guidelines are valuable but do NOT block merges.** Discuss in PR, don't gate on.

This keeps enforcement predictable and prevents bike-shedding. If you want something enforced, write a SwiftLint custom rule or accept that it's advisory.

## Enforcement Chain [ENFORCED]

### 1. Formatting (swiftformat)
- Non-destructive formatting only
- Must preserve semantics
- Command: `swiftformat . --lint` (if swiftformat exists)

### 2. Linting (swiftlint)
- Enforces code style rules in `.swiftlint.yml`
- Command: `swiftlint lint`
- Build FAILS if lint fails

### 3. Build
- Type errors caught by compiler
- No implicit unwrapping of optionals in new code

### 4. Tests
- All tests must pass
- New code should have test coverage

## Integrator Gate (Final Patchset)

Integrator MUST run these commands in order:

```bash
# 1. Format check (if available)
if command -v swiftformat &> /dev/null; then
  swiftformat . --lint
fi

# 2. Lint
swiftlint lint

# 3. Build + Test (via MCP or xcodebuild)
```

If ANY step fails → build is BLOCKED.

## Non-Enforceable Preferences [ADVISORY]

These are guidelines, not gates:
- Naming conventions beyond what lint catches
- Comment style preferences
- Architectural opinions

Discuss in PR, don't block on.

---

## Related Rules

- See `.claude/rules/modern-swift.md` for architecture guidelines (ADVISORY)
- See `.claude/rules/design-bar.md` for UI quality guidelines
