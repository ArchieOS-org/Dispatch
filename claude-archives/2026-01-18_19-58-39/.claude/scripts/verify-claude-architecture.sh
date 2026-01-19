#!/bin/bash
# verify-claude-architecture.sh
# Deterministic verification of Claude Code agent architecture
# No external dependencies beyond bash/grep/sed/awk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

echo "=============================================="
echo "Claude Code Architecture Verification"
echo "=============================================="
echo ""

# =============================================
# SECTION 1: Required Files Exist
# =============================================
echo "--- Required Files ---"

REQUIRED_FILES=(
  "rules/design-bar.md"
  "rules/style-enforcement.md"
  "rules/modern-swift.md"
  "contracts/_template.md"
  "debt/STRUCTURAL_DEBT.md"
  "agents/dispatch-planner.md"
  "agents/dispatch-explorer.md"
  "agents/feature-owner.md"
  "agents/data-integrity.md"
  "agents/ui-polish.md"
  "agents/integrator.md"
  "agents/swift-debugger.md"
  "agents/jobs-critic.md"
  "agents/xcode-pilot.md"
)

REQUIRED_SKILLS=(
  "skills/swiftui-a11y-audit.md"
  "skills/swiftui-layout-sanity.md"
  "skills/empty-loading-error-states.md"
  "skills/copywriting-tightener.md"
  "skills/performance-smoke.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$CLAUDE_DIR/$file" ]]; then
    pass "$file exists"
  else
    fail "$file MISSING"
  fi
done

for file in "${REQUIRED_SKILLS[@]}"; do
  if [[ -f "$CLAUDE_DIR/$file" ]]; then
    pass "$file exists"
  else
    fail "$file MISSING"
  fi
done

echo ""

# =============================================
# SECTION 2: Agent YAML Frontmatter Validation
# =============================================
echo "--- Agent YAML Frontmatter ---"

VALID_MODELS="opus|sonnet|haiku|inherit"

for agent_file in "$CLAUDE_DIR"/agents/*.md; do
  agent_name=$(basename "$agent_file")

  # Check for YAML frontmatter delimiters
  first_line=$(head -n 1 "$agent_file")
  if [[ "$first_line" != "---" ]]; then
    fail "$agent_name: Missing YAML frontmatter (no opening ---)"
    continue
  fi

  # Extract frontmatter using awk (more portable than head -n -1)
  frontmatter=$(awk 'NR==1 && /^---$/ {start=1; next} start && /^---$/ {exit} start {print}' "$agent_file")

  # Check required fields
  has_name=$(echo "$frontmatter" | grep -c "^name:" 2>/dev/null || echo 0)
  has_desc=$(echo "$frontmatter" | grep -c "^description:" 2>/dev/null || echo 0)
  has_model=$(echo "$frontmatter" | grep -c "^model:" 2>/dev/null || echo 0)
  has_tools=$(echo "$frontmatter" | grep -c "^tools:" 2>/dev/null || echo 0)

  errors=0

  if [[ $has_name -eq 0 ]]; then
    fail "$agent_name: Missing 'name:' field"
    errors=$((errors + 1))
  fi
  if [[ $has_desc -eq 0 ]]; then
    fail "$agent_name: Missing 'description:' field"
    errors=$((errors + 1))
  fi
  if [[ $has_model -eq 0 ]]; then
    fail "$agent_name: Missing 'model:' field"
    errors=$((errors + 1))
  else
    model_value=$(echo "$frontmatter" | grep "^model:" | sed 's/model: *//')
    if ! echo "$model_value" | grep -qE "^($VALID_MODELS)$"; then
      fail "$agent_name: Invalid model '$model_value' (must be opus|sonnet|haiku|inherit)"
      errors=$((errors + 1))
    fi
  fi
  if [[ $has_tools -eq 0 ]]; then
    fail "$agent_name: Missing 'tools:' field"
    errors=$((errors + 1))
  fi

  # If all checks passed for this agent
  if [[ $errors -eq 0 ]]; then
    pass "$agent_name: Valid frontmatter"
  fi
done

echo ""

# =============================================
# SECTION 3: No Task Tool in Agents
# =============================================
echo "--- Task Tool Check (must be 0) ---"

task_tool_count=$(grep -l '"Task"' "$CLAUDE_DIR"/agents/*.md 2>/dev/null | grep -v "Task Graph" | wc -l | tr -d ' ')

if [[ "$task_tool_count" -eq 0 ]]; then
  pass "No agent declares Task tool"
else
  fail "Found $task_tool_count agents with Task tool reference"
  grep -l '"Task"' "$CLAUDE_DIR"/agents/*.md 2>/dev/null | grep -v "Task Graph" || true
fi

echo ""

# =============================================
# SECTION 4: Deprecated Context7 Tool Names
# =============================================
echo "--- Deprecated Context7 Tools ---"

# Exclude scripts directory from search
deprecated_count=$(grep -r "get-library-docs" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/skills" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$deprecated_count" -eq 0 ]]; then
  pass "No deprecated 'get-library-docs' references"
else
  fail "Found $deprecated_count references to deprecated 'get-library-docs'"
  grep -r "get-library-docs" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/skills" 2>/dev/null || true
fi

# Check for correct tool names
query_docs_count=$(grep -r "query-docs" "$CLAUDE_DIR/agents" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$query_docs_count" -ge 2 ]]; then
  pass "Found $query_docs_count references to 'query-docs' (expected >=2)"
else
  warn "Only $query_docs_count references to 'query-docs' (expected >=2)"
fi

echo ""

# =============================================
# SECTION 5: Contract Template Validation
# =============================================
echo "--- Contract Template ---"

template_file="$CLAUDE_DIR/contracts/_template.md"

if grep -q "UI Review Required:" "$template_file" 2>/dev/null; then
  pass "Contract template has 'UI Review Required' field"
else
  fail "Contract template missing 'UI Review Required' field"
fi

if grep -q "JOBS CRITIQUE:" "$template_file" 2>/dev/null; then
  pass "Contract template has 'JOBS CRITIQUE' field"
else
  fail "Contract template missing 'JOBS CRITIQUE' field"
fi

echo ""

# =============================================
# SECTION 6: Key String Standardization
# =============================================
echo "--- Output String Standards ---"

# Check for non-standard Jobs Critique format (excluding section headers)
jobs_old_format=$(grep -r "Jobs Critique:" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" 2>/dev/null | grep -v "## Jobs Critique" | grep -v "written by jobs-critic" | grep -v "section" | wc -l | tr -d ' ')

if [[ "$jobs_old_format" -eq 0 ]]; then
  pass "All Jobs Critique field references use standardized format"
else
  warn "Found $jobs_old_format non-standard 'Jobs Critique:' field references"
fi

# Check for DESIGN BAR format
design_bar_format=$(grep -r "DESIGN BAR:" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$design_bar_format" -ge 3 ]]; then
  pass "Found $design_bar_format 'DESIGN BAR:' references"
else
  warn "Only $design_bar_format 'DESIGN BAR:' references (expected >=3)"
fi

echo ""

# =============================================
# SUMMARY
# =============================================
echo "=============================================="
echo "SUMMARY"
echo "=============================================="
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo -e "Warnings: ${YELLOW}$WARN_COUNT${NC}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}ARCHITECTURE VERIFICATION: PASS${NC}"
  exit 0
else
  echo -e "${RED}ARCHITECTURE VERIFICATION: FAIL${NC}"
  exit 1
fi
