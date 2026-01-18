#!/bin/bash
#
# Check for unsafe Binding patterns that cause SwiftUI runtime warnings.
#
# Detects: Binding setters containing dispatch() or appState. mutations
#          WITHOUT a Task { wrapper (which causes "Publishing changes from
#          within view updates is not allowed" warnings)
#
# Usage: ./scripts/check_binding_patterns.sh [directory]
#        Default directory: Dispatch/
#
# Exit codes:
#   0 - No violations found
#   1 - Violations found
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Resolve symlinks (macOS /tmp -> /private/tmp)
SEARCH_DIR="${1:-$REPO_ROOT/Dispatch}"
if [ -L "$SEARCH_DIR" ]; then
  SEARCH_DIR="$(cd "$SEARCH_DIR" && pwd -P)"
elif [ -d "$SEARCH_DIR" ]; then
  SEARCH_DIR="$(cd "$SEARCH_DIR" && pwd -P)"
fi

# Color output (if terminal supports it)
RED=""
GREEN=""
YELLOW=""
RESET=""
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RESET='\033[0m'
fi

echo "Checking for unsafe Binding patterns in: $SEARCH_DIR"
echo ""

VIOLATIONS=0
VIOLATION_DETAILS=""

# Find all Swift files and check each one
while IFS= read -r -d '' file; do
  # Use perl with recursive regex for proper brace matching
  # The (?:(?>[^{}]+)|(\{(?:(?>[^{}]+)|(?1))*\}))* pattern handles nested braces
  violations_in_file=$(perl -0777 -ne '
    use strict;
    use warnings;

    # Recursive regex to match balanced braces
    # (?<BRACES>\{(?:[^{}]|(?&BRACES))*\}) matches { ... } with any nesting
    my $text = $_;

    # Find all Binding( patterns
    while ($text =~ /Binding\s*\(/g) {
      my $start_pos = $-[0];
      my $line_num = 1 + (() = substr($text, 0, $start_pos) =~ /\n/g);

      # Find the matching ) for Binding(
      my $paren_depth = 1;
      my $pos = pos($text);
      my $binding_content = "";

      while ($paren_depth > 0 && $pos < length($text)) {
        my $char = substr($text, $pos, 1);
        if ($char eq "(") {
          $paren_depth++;
        } elsif ($char eq ")") {
          $paren_depth--;
        }
        $binding_content .= $char if $paren_depth > 0;
        $pos++;
      }

      # Check if this Binding has a set: closure with dispatch/appState
      # and whether it has Task { wrapper

      # Find set: followed by a closure
      if ($binding_content =~ /set:\s*\{/) {
        my $set_start = $-[0];
        my $after_set = substr($binding_content, $set_start);

        # Find the closing brace of the set closure (with proper nesting)
        if ($after_set =~ /set:\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\})/) {
          my $set_closure = $1;

          # Check for dispatch( or appState. in the closure
          if ($set_closure =~ /(?:dispatch\s*\(|appState\.)/) {
            # Check if Task { exists BEFORE the dispatch/appState call
            # This is the safe pattern
            unless ($set_closure =~ /Task\s*\{/) {
              print "$line_num\n";
            }
          }
        }
      }
    }
  ' "$file" 2>/dev/null)

  if [ -n "$violations_in_file" ]; then
    # Get relative path for cleaner output
    rel_path="${file#$REPO_ROOT/}"

    # Print each line number
    while IFS= read -r line_num; do
      if [ -n "$line_num" ]; then
        VIOLATIONS=$((VIOLATIONS + 1))
        VIOLATION_DETAILS="${VIOLATION_DETAILS}${RED}VIOLATION:${RESET} ${rel_path}:${line_num}\n"
        VIOLATION_DETAILS="${VIOLATION_DETAILS}  Binding set: closure with dispatch() or appState. mutation\n"
        VIOLATION_DETAILS="${VIOLATION_DETAILS}  Missing Task { @MainActor in ... } wrapper\n\n"
      fi
    done <<< "$violations_in_file"
  fi

done < <(find "$SEARCH_DIR" -name "*.swift" -type f -print0 2>/dev/null)

# Summary
if [ $VIOLATIONS -eq 0 ]; then
  echo -e "${GREEN}No violations found.${RESET}"
  echo ""
  echo "All Binding setters with dispatch() or appState. mutations"
  echo "are properly wrapped in Task { @MainActor in ... }"
  exit 0
else
  echo -e "$VIOLATION_DETAILS"
  echo "========================================"
  echo -e "${RED}Found $VIOLATIONS violation(s).${RESET}"
  echo ""
  echo "FIX: Wrap mutations in Task { @MainActor in ... } to defer"
  echo "     execution and avoid 'Publishing changes from within"
  echo "     view updates' warnings."
  echo ""
  echo "Example:"
  echo "  // BAD"
  echo "  Binding("
  echo "    get: { state.value },"
  echo "    set: { appState.dispatch(.setValue(\$0)) }"
  echo "  )"
  echo ""
  echo "  // GOOD"
  echo "  Binding("
  echo "    get: { state.value },"
  echo "    set: { newValue in"
  echo "      Task { @MainActor in"
  echo "        appState.dispatch(.setValue(newValue))"
  echo "      }"
  echo "    }"
  echo "  )"
  exit 1
fi
