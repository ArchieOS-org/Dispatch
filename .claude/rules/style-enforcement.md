# Style Enforcement Policy

## Core Principle
**If it can't be enforced by lint/format/build/test, it's a preference, not a rule.**

We follow the Airbnb philosophy: rules must be mechanically enforceable.

## Enforcement Chain

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

## Integrator Gate (PATCHSET 4)

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

## Non-Enforceable Preferences (NOT rules)

These are guidelines, not gates:
- Naming conventions beyond what lint catches
- Comment style preferences
- Architectural opinions

Discuss in PR, don't block on.
