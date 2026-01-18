## Interface Lock

**Feature**: Binding Pattern Safeguards
**Created**: 2026-01-18
**Status**: locked
**Lock Version**: v1
**UI Review Required**: NO

---

### Complexity Indicators

Check all that apply to determine patchset plan:

- [ ] **Schema changes** (adds data-integrity agent, PATCHSET 1.5)
- [ ] **Complex UI** (adds jobs-critic + ui-polish, PATCHSET 2.5)
- [ ] **High-risk flow** (adds xcode-pilot, PATCHSET 3)
- [ ] **Unfamiliar area** (adds dispatch-explorer)

**Note**: All indicators unchecked. This is standard CI/lint/test tooling work.

### Patchset Plan

Based on checked indicators (none):

| Patchset | Gate | Agents |
|----------|------|--------|
| 1 | Compiles (scripts work, lint config valid) | feature-owner |
| 2 | Tests pass, all criteria met | feature-owner, integrator |

---

### Background

We fixed 5 instances where `Binding` setters called `dispatch()` or mutated `appState` synchronously. This causes SwiftUI runtime warnings:

> "Publishing changes from within view updates is not allowed, this will cause undefined behavior."

**The correct pattern** wraps mutations in `Task { @MainActor in }` to defer execution to the next run loop:

```swift
// BAD - causes "Publishing changes from within view updates" warning
Binding(
  get: { appState.value },
  set: { appState.dispatch(.setValue($0)) }  // Synchronous mutation!
)

// GOOD - defers mutation to next run loop
Binding(
  get: { appState.value },
  set: { newValue in
    Task { @MainActor in
      appState.dispatch(.setValue(newValue))
    }
  }
)
```

### Contract

- New/changed model fields: None
- DTO/API changes: None
- State/actions added: None
- Migration required: N

### Acceptance Criteria (4 deliverables)

1. **CI check script** (`scripts/check_binding_patterns.sh`):
   - Detects `Binding(` patterns with `set:` containing `dispatch(` or `appState.` without `Task {`
   - Exits non-zero if violations found, zero if clean
   - Integrated into `scripts/ci_mirror.sh` as a lint step

2. **Documentation** (`CLAUDE.md`):
   - New "## Common Anti-Patterns" section after "Code Style Guidelines"
   - Documents the binding anti-pattern with correct pattern example
   - Explains why the anti-pattern causes issues

3. **Custom SwiftLint rule** (`.swiftlint.yml`):
   - `custom_rules:` entry named `binding_sync_mutation`
   - Flags `Binding.*set:.*dispatch\(` or `Binding.*set:.*appState\.` without Task wrapper
   - Warning severity (not error) for gradual adoption

4. **Architectural test** (`DispatchTests/BindingPatternTests.swift`):
   - Scans source files for violation patterns
   - Fails test if violations found
   - Documents allowed exceptions (if any)

### Non-goals (prevents scope creep)

- Fixing any existing violations (already fixed in previous work)
- Runtime detection or assertions
- Changes to AppState or action dispatch mechanism
- Any UI changes

### Compatibility Plan

- **Backward compatibility**: N/A (tooling only)
- **Default when missing**: N/A
- **Rollback strategy**: Revert the 4 files; no data impact

---

### Ownership

- **feature-owner**: Implement all 4 deliverables (script, docs, lint rule, test)
- **data-integrity**: Not needed (no schema)

---

### Context7 Queries

Log all Context7 lookups here (see `.claude/rules/context7-mandatory.md`):

- N/A for pure tooling/CI work (no framework APIs being called)

---

### Context7 Attestation (written by feature-owner at PATCHSET 1)

**CONTEXT7 CONSULTED**: N/A
**Libraries Queried**: N/A

| Query | Pattern Used |
|-------|--------------|
| N/A - pure CI/lint/test tooling | No framework code written |

**N/A**: Valid for this contract because all deliverables are shell scripts, lint config, and test scaffolding with no SwiftUI/framework API usage.

---

### Jobs Critique (written by jobs-critic agent)

**JOBS CRITIQUE**: N/A (UI Review Required: NO)
**Reviewed**: N/A

#### Checklist

N/A - No UI changes in this contract.

#### Verdict Notes

Skipped per contract: UI Review Required is NO.

---

### Implementation Notes

**Files to create/modify:**

| File | Action |
|------|--------|
| `scripts/check_binding_patterns.sh` | Create |
| `scripts/ci_mirror.sh` | Modify (add lint step) |
| `CLAUDE.md` | Modify (add anti-patterns section) |
| `.swiftlint.yml` | Modify (add custom rule) |
| `DispatchTests/BindingPatternTests.swift` | Create |

**Regex patterns for detection:**

The core detection pattern (for script and test):
```bash
# Multiline: Binding with set: containing dispatch( or appState. without Task {
grep -Pzo 'Binding\s*\([^)]*set:\s*\{[^}]*(?:dispatch\(|appState\.)[^}]*\}' \
  | grep -v 'Task {'
```

**SwiftLint custom rule limitations:**
- SwiftLint regex is single-line by default
- May need simplified pattern that catches common cases
- Test file provides thorough multiline detection as backup

---

**IMPORTANT**:
- UI Review Required: NO - integrator skips Jobs Critique check
- Context7 Attestation: N/A is valid for pure tooling work
- All 4 acceptance criteria must pass for integrator DONE
