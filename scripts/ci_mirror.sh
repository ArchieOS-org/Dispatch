#!/bin/bash
#
# CI Mirror: Run all gates, never fail-fast, report everything.
#
# Runs in a clean temp workspace to avoid dirtying the repo.
# Compatible with bash 3.2 (macOS default).
#
# Usage: ./scripts/ci_mirror.sh
#
# Outputs:
#   artifacts/logs/<step>.log
#   artifacts/results.tsv
#   artifacts/summary.txt
#

# No -e! We handle errors manually per step.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS="$REPO_ROOT/artifacts"
LOGS="$ARTIFACTS/logs"

# Results file (bash 3.2 compatible - no associative arrays)
RESULTS_FILE="$ARTIFACTS/results.tsv"

# Tool paths
SWIFTFORMAT="$REPO_ROOT/tools/swiftformat"
SWIFTLINT="$REPO_ROOT/tools/swiftlint"

# Temp workspace (clean copy)
WORKSPACE=""

# Track overall failure
FAILED=0

# Destinations
DEST_MACOS="platform=macOS"
DEST_IPHONE=""
DEST_IPAD=""
IOS_SUPPORTED=false
IOS_SKIP_REASON=""  # Carries the real reason if iOS is unsupported

#######################################
# Cleanup on exit
#######################################
cleanup() {
  if [ -n "$WORKSPACE" ] && [ -d "$WORKSPACE" ]; then
    rm -rf "$WORKSPACE"
  fi
}
trap cleanup EXIT

#######################################
# Record result idempotently (one row per step)
# Deletes existing entry before appending new one.
# Uses awk for proper field match (not substring match).
#######################################
record_result() {
  local name="$1"
  local status="$2"

  # Remove any existing entry for this step (proper field match with awk)
  # grep -vF would match substrings, awk matches exact first field
  if [ -f "$RESULTS_FILE" ]; then
    awk -F'\t' -v n="$name" '$1 != n' "$RESULTS_FILE" > "$RESULTS_FILE.tmp" 2>/dev/null || true
    mv "$RESULTS_FILE.tmp" "$RESULTS_FILE"
  fi

  # Append new result
  printf "%s\t%s\n" "$name" "$status" >> "$RESULTS_FILE"
}

#######################################
# Run a step, capture status, continue.
# Never fails the script — records result and moves on.
#
# Uses real pipeline (not process substitution) so PIPESTATUS works.
#######################################
run_step() {
  local name="$1"
  shift
  local log_file="$LOGS/${name// /_}.log"

  echo ""
  echo "========================================"
  echo "  $name"
  echo "========================================"

  # Real pipeline: command | tee
  # PIPESTATUS[0] captures the command's exit code
  set +e
  "$@" 2>&1 | tee "$log_file"
  local status=${PIPESTATUS[0]}
  # Do NOT re-enable -e

  # Record to TSV file (idempotent)
  record_result "$name" "$status"

  if [ "$status" -ne 0 ]; then
    echo "$name failed (exit $status)"
    FAILED=1
  else
    echo "$name passed"
  fi
}

#######################################
# Record a skipped step
#######################################
record_skip() {
  local name="$1"
  local reason="$2"
  echo "Skipping $name ($reason)"
  record_result "$name" "SKIPPED"
}

#######################################
# Setup: create clean workspace
#######################################
setup() {
  echo "Setting up CI Mirror..."

  # Clean artifacts
  rm -rf "$ARTIFACTS"
  mkdir -p "$LOGS"

  # Initialize results file
  : > "$RESULTS_FILE"

  # Create temp workspace
  WORKSPACE=$(mktemp -d)
  echo "Workspace: $WORKSPACE"

  # Rsync repo to temp (exclude only non-source directories)
  # Source files are NOT excluded - linters must handle exclusions via their own configs
  rsync -a --exclude='.git' --exclude='artifacts' --exclude='DerivedData*' \
    "$REPO_ROOT/" "$WORKSPACE/"

  # Generate Secrets.swift in temp workspace (never touches real repo)
  local secrets_path="$WORKSPACE/Dispatch/App/Configuration/Secrets.swift"
  if [ ! -f "$secrets_path" ]; then
    echo "Generating Secrets.swift stub in workspace..."
    mkdir -p "$(dirname "$secrets_path")"
    if [ -f "${secrets_path}.example" ]; then
      cp "${secrets_path}.example" "$secrets_path"
    else
      cat > "$secrets_path" << 'SECRETS_EOF'
//
//  Secrets.swift (CI-generated)
//

import Foundation

enum Secrets {
  static let supabaseURL = "https://ci-placeholder.supabase.co"
  static let supabaseAnonKey = "ci-placeholder-key"
}
SECRETS_EOF
    fi
  fi
}

#######################################
# Preflight: verify tools, configs, and Xcode SDK
#######################################
preflight() {
  echo ""
  echo "=== Preflight Checks ==="

  # Check Xcode toolchain
  echo "Xcode toolchain:"
  echo "  xcode-select: $(xcode-select -p)"
  echo "  Xcode: $(xcodebuild -version | head -1)"

  # Check iOS Simulator SDK exists (toolchain issue, not scheme)
  local sdks
  sdks=$(xcodebuild -showsdks 2>/dev/null || true)
  local has_ios_sdk=false
  if echo "$sdks" | grep -q "iphonesimulator"; then
    has_ios_sdk=true
    echo "  iOS Simulator SDK available"
  else
    echo "  iOS Simulator SDK NOT found (check xcode-select)"
  fi

  # Check tools exist
  echo ""
  if [ ! -x "$SWIFTFORMAT" ]; then
    echo "SwiftFormat not found at $SWIFTFORMAT"
    echo "   Run: ./scripts/install_tools.sh"
    exit 1
  fi
  if [ ! -x "$SWIFTLINT" ]; then
    echo "SwiftLint not found at $SWIFTLINT"
    echo "   Run: ./scripts/install_tools.sh"
    exit 1
  fi

  echo "SwiftFormat: $("$SWIFTFORMAT" --version)"
  echo "SwiftLint: $("$SWIFTLINT" version)"

  # Validate .swiftformat.ci doesn't have unknown rules
  echo ""
  echo "Validating .swiftformat.ci..."
  local validation
  validation=$("$SWIFTFORMAT" --lint --config "$REPO_ROOT/.swiftformat.ci" --dryrun "$WORKSPACE/Dispatch" 2>&1 || true)
  if echo "$validation" | grep -qiE "unknown (rule|option)"; then
    echo ".swiftformat.ci contains unsupported rules/options:"
    echo "$validation" | grep -iE "unknown (rule|option)"
    echo ""
    echo "Regenerate with: ./scripts/generate_swiftformat_ci.sh"
    exit 1
  fi
  echo ".swiftformat.ci is compatible"

  # Check scheme destinations
  echo ""
  echo "Checking scheme destinations..."
  local destinations
  destinations=$(xcodebuild -showdestinations -project "$WORKSPACE/Dispatch.xcodeproj" -scheme Dispatch 2>/dev/null || true)

  # iOS support requires BOTH SDK and scheme destinations
  if [ "$has_ios_sdk" = "true" ] && echo "$destinations" | grep -q "platform:iOS Simulator"; then
    IOS_SUPPORTED=true
    IOS_SKIP_REASON=""
    echo "iOS Simulator destinations available"
  else
    IOS_SUPPORTED=false
    if [ "$has_ios_sdk" != "true" ]; then
      IOS_SKIP_REASON="iOS Simulator SDK not found (check xcode-select -p)"
      echo "iOS builds skipped: $IOS_SKIP_REASON"
    else
      IOS_SKIP_REASON="scheme doesn't expose iOS Simulator"
      echo "iOS builds skipped: $IOS_SKIP_REASON"
    fi
  fi

  if echo "$destinations" | grep -q "platform:macOS"; then
    echo "macOS destination available"
  else
    echo "macOS destination NOT available — builds may fail"
  fi
}

#######################################
# Resolve simulator destinations
# Picks any available iPhone and iPad
#######################################
resolve_destinations() {
  if [ "$IOS_SUPPORTED" != "true" ]; then
    echo "Skipping simulator resolution (iOS not supported by scheme)"
    return
  fi

  echo ""
  echo "Resolving simulator destinations..."

  local devices
  devices=$(xcrun simctl list devices available -j 2>/dev/null || echo '{}')

  # Find first available iPhone
  DEST_IPHONE=$(echo "$devices" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for runtime, devs in data.get('devices', {}).items():
        if 'iOS' not in runtime and 'Simulator' not in runtime:
            continue
        for d in devs:
            if d.get('isAvailable') and 'iPhone' in d.get('name', ''):
                print(f\"id={d['udid']}\")
                sys.exit(0)
except:
    pass
print('')
" 2>/dev/null || echo "")

  # Find first available iPad
  DEST_IPAD=$(echo "$devices" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for runtime, devs in data.get('devices', {}).items():
        if 'iOS' not in runtime and 'Simulator' not in runtime:
            continue
        for d in devs:
            if d.get('isAvailable') and 'iPad' in d.get('name', ''):
                print(f\"id={d['udid']}\")
                sys.exit(0)
except:
    pass
print('')
" 2>/dev/null || echo "")

  echo "  macOS:  $DEST_MACOS"
  echo "  iPhone: ${DEST_IPHONE:-NOT FOUND}"
  echo "  iPad:   ${DEST_IPAD:-NOT FOUND}"
}

#######################################
# Lint steps
#######################################
lint_swiftlint() {
  run_step "SwiftLint" \
    "$SWIFTLINT" lint --strict "$WORKSPACE/Dispatch" --config "$REPO_ROOT/.swiftlint.yml"
}

lint_swiftformat() {
  run_step "SwiftFormat" \
    "$SWIFTFORMAT" "$WORKSPACE/Dispatch" --lint --config "$REPO_ROOT/.swiftformat.ci"
}

lint_design_gate() {
  run_step "Design Gate" bash -c "
    # Guard 1: DomainDesignBridge must NOT live in Design/
    if [ -f '$WORKSPACE/Dispatch/Design/DomainDesignBridge.swift' ]; then
      echo 'DomainDesignBridge.swift must not be in Dispatch/Design/'
      exit 1
    fi

    # Guard 2: No domain types or forbidden imports in Design/
    DOMAIN_TYPES='\\b(User|Priority|Role|ClaimState|AppState|Listing|TaskItem|Activity|WorkItem)\\b'
    FORBIDDEN_IMPORTS='^import[[:space:]]+(Features|SharedUI)\\b'
    VIOLATIONS=\$(grep -rEn --include='*.swift' -E \"\$FORBIDDEN_IMPORTS|\$DOMAIN_TYPES\" '$WORKSPACE/Dispatch/Design' 2>/dev/null || true)
    if [ -n \"\$VIOLATIONS\" ]; then
      echo 'Design/ contains domain imports or types:'
      echo \"\$VIOLATIONS\"
      exit 1
    fi
    echo 'Design/ is clean of domain dependencies'
  "
}

#######################################
# Build steps
#######################################
build_macos() {
  run_step "Build macOS" \
    xcodebuild build \
      -project "$WORKSPACE/Dispatch.xcodeproj" \
      -scheme Dispatch \
      -destination "$DEST_MACOS" \
      -configuration Debug \
      -derivedDataPath "$WORKSPACE/DerivedData-macos" \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
}

build_iphone() {
  if [ "$IOS_SUPPORTED" != "true" ]; then
    record_skip "Build iPhone" "$IOS_SKIP_REASON"
    return
  fi
  if [ -z "$DEST_IPHONE" ]; then
    record_skip "Build iPhone" "no iPhone simulator available"
    return
  fi

  run_step "Build iPhone" \
    xcodebuild build \
      -project "$WORKSPACE/Dispatch.xcodeproj" \
      -scheme Dispatch \
      -destination "$DEST_IPHONE" \
      -configuration Debug \
      -derivedDataPath "$WORKSPACE/DerivedData-iphone" \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
}

build_ipad() {
  if [ "$IOS_SUPPORTED" != "true" ]; then
    record_skip "Build iPad" "$IOS_SKIP_REASON"
    return
  fi
  if [ -z "$DEST_IPAD" ]; then
    record_skip "Build iPad" "no iPad simulator available"
    return
  fi

  run_step "Build iPad" \
    xcodebuild build \
      -project "$WORKSPACE/Dispatch.xcodeproj" \
      -scheme Dispatch \
      -destination "$DEST_IPAD" \
      -configuration Debug \
      -derivedDataPath "$WORKSPACE/DerivedData-ipad" \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
}

#######################################
# Get result for a step from TSV file
# Uses awk for exact first-field match (same as record_result)
#######################################
get_result() {
  local name="$1"
  awk -F'\t' -v n="$name" '$1==n {print $2; found=1} END{if(!found) print "SKIPPED"}' "$RESULTS_FILE" 2>/dev/null
}

#######################################
# Summary
#######################################
summary() {
  echo ""
  echo "========================================"
  echo "           CI MIRROR SUMMARY"
  echo "========================================"

  local summary_file="$ARTIFACTS/summary.txt"
  : > "$summary_file"

  # Read results from TSV file (bash 3.2 compatible)
  while IFS=$'\t' read -r step status; do
    local icon
    if [ "$status" = "0" ]; then
      icon="PASS"
    elif [ "$status" = "SKIPPED" ]; then
      icon="SKIP"
    else
      icon="FAIL"
    fi
    echo "$icon $step (exit: $status)" | tee -a "$summary_file"
  done < "$RESULTS_FILE"

  echo "" | tee -a "$summary_file"
  echo "Logs: $LOGS/" | tee -a "$summary_file"
  echo "" | tee -a "$summary_file"

  if [ $FAILED -eq 1 ]; then
    echo "CI WOULD FAIL" | tee -a "$summary_file"
    echo ""
    echo "Failed steps:"
    while IFS=$'\t' read -r step status; do
      if [ "$status" != "0" ] && [ "$status" != "SKIPPED" ]; then
        echo "  - $step -> $LOGS/${step// /_}.log"
      fi
    done < "$RESULTS_FILE"
  else
    echo "CI WOULD PASS" | tee -a "$summary_file"
  fi
}

#######################################
# Main
#######################################
main() {
  setup
  preflight
  resolve_destinations

  echo ""
  echo "Running all gates (no fail-fast)..."

  # Lint
  lint_swiftlint
  lint_swiftformat
  lint_design_gate

  # Build (compile-only sweep)
  build_macos
  build_iphone
  build_ipad

  # Summary
  summary

  exit $FAILED
}

main "$@"
