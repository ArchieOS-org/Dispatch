#!/bin/bash
#
# Generate .swiftformat.ci from .swiftformat.airbnb + .swiftformat
#
# FAILS HARD if any rules are not supported by the pinned SwiftFormat version.
# This forces a conscious decision when updating configs.
#
# Compatible with bash 3.2:
#   - No associative arrays
#   - No subshells in loops (uses while read < file, not cat | while)
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SWIFTFORMAT="$REPO_ROOT/tools/swiftformat"
OUTPUT="$REPO_ROOT/.swiftformat.ci"

if [ ! -x "$SWIFTFORMAT" ]; then
  echo "SwiftFormat not found. Run: ./scripts/install_tools.sh"
  exit 1
fi

echo "SwiftFormat version: $("$SWIFTFORMAT" --version)"
echo ""

# Create temp files
SUPPORTED_RULES_FILE=$(mktemp)
COMBINED_FILE=$(mktemp)
TEMP_OUTPUT=$(mktemp)
UNSUPPORTED_RULES_FILE=$(mktemp)
UNSUPPORTED_OPTIONS_FILE=$(mktemp)
trap "rm -f '$SUPPORTED_RULES_FILE' '$COMBINED_FILE' '$TEMP_OUTPUT' '$UNSUPPORTED_RULES_FILE' '$UNSUPPORTED_OPTIONS_FILE'" EXIT

# Get supported rules (one per line)
echo "Fetching supported rules..."
"$SWIFTFORMAT" --rules 2>&1 | grep -E '^\s+\w' | awk '{print $1}' | sort -u > "$SUPPORTED_RULES_FILE"

# Combine config files into temp file (avoids cat | while subshell)
cat "$REPO_ROOT/.swiftformat.airbnb" "$REPO_ROOT/.swiftformat" > "$COMBINED_FILE" 2>/dev/null || true

# Initialize outputs
: > "$TEMP_OUTPUT"
: > "$UNSUPPORTED_RULES_FILE"
: > "$UNSUPPORTED_OPTIONS_FILE"

# Option translations (hyphenated -> non-hyphenated for 0.54.6)
# SwiftFormat 0.54.6 uses non-hyphenated option names
translate_option_line() {
  local line="$1"
  # Translate known hyphenated options to non-hyphenated
  # Options that don't exist in 0.54.6 are marked as SKIP_UNSUPPORTED
  echo "$line" \
    | sed 's/^--swift-version /--swiftversion /' \
    | sed 's/^--language-mode /--SKIP_UNSUPPORTED /' \
    | sed 's/^--prefer-synthesized-init-for-internal-structs /--SKIP_UNSUPPORTED /' \
    | sed 's/^--import-grouping /--importgrouping /' \
    | sed 's/^--trailing-commas /--commas /' \
    | sed 's/^--trim-whitespace /--trimwhitespace /' \
    | sed 's/^--indent-strings /--indentstrings /' \
    | sed 's/^--wrap-arguments /--wraparguments /' \
    | sed 's/^--wrap-parameters /--wrapparameters /' \
    | sed 's/^--wrap-collections /--wrapcollections /' \
    | sed 's/^--wrap-conditions /--wrapconditions /' \
    | sed 's/^--wrap-return-type /--wrapreturntype /' \
    | sed 's/^--wrap-effects /--wrapeffects /' \
    | sed 's/^--closing-paren /--closingparen /' \
    | sed 's/^--call-site-paren /--callsiteparen /' \
    | sed 's/^--wrap-type-aliases /--wraptypealiases /' \
    | sed 's/^--allow-partial-wrapping /--SKIP_UNSUPPORTED /' \
    | sed 's/^--func-attributes /--funcattributes /' \
    | sed 's/^--computed-var-attributes /--computedvarattrs /' \
    | sed 's/^--stored-var-attributes /--storedvarattrs /' \
    | sed 's/^--complex-attributes /--complexattrs /' \
    | sed 's/^--type-attributes /--typeattributes /' \
    | sed 's/^--wrap-ternary /--wrapternary /' \
    | sed 's/^--wrap-string-interpolation /--SKIP_UNSUPPORTED /' \
    | sed 's/^--mark-struct-threshold /--structthreshold /' \
    | sed 's/^--mark-enum-threshold /--enumthreshold /' \
    | sed 's/^--organize-types /--organizetypes /' \
    | sed 's/^--visibility-order /--SKIP_UNSUPPORTED /' \
    | sed 's/^--type-order /--SKIP_UNSUPPORTED /' \
    | sed 's/^--sort-swiftui-properties /--SKIP_UNSUPPORTED /' \
    | sed 's/^--type-body-marks /--SKIP_UNSUPPORTED /' \
    | sed 's/^--extension-acl /--extensionacl /' \
    | sed 's/^--pattern-let /--patternlet /' \
    | sed 's/^--property-types /--SKIP_UNSUPPORTED /' \
    | sed 's/^--type-blank-lines /--typeblanklines /' \
    | sed 's/^--empty-braces /--emptybraces /' \
    | sed 's/^--operator-func /--operatorfunc /' \
    | sed 's/^--some-any /--someany /' \
    | sed 's/^--else-position /--elseposition /' \
    | sed 's/^--guard-else /--guardelse /' \
    | sed 's/^--single-line-for-each /--SKIP_UNSUPPORTED /' \
    | sed 's/^--short-optionals /--shortoptionals /' \
    | sed 's/^--doc-comments /--doccomments /' \
    | sed 's/^--modifier-order /--modifierorder /' \
    | sed 's/^--max-width /--maxwidth /'
}

# Process config (read from file, not pipe)
echo "Processing config..."
while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments
  if [ -z "$line" ] || echo "$line" | grep -qE '^#'; then
    echo "$line" >> "$TEMP_OUTPUT"
    continue
  fi

  # Check if this is a --rules line
  if echo "$line" | grep -qE '^--rules[[:space:]]+'; then
    # Extract rules (may be comma-separated)
    rules_part=$(echo "$line" | sed 's/^--rules[[:space:]]*//')

    # Handle comma-separated rules using IFS (no subshell)
    # Save and restore IFS
    OLD_IFS="$IFS"
    IFS=','
    for rule in $rules_part; do
      # Trim whitespace
      rule=$(echo "$rule" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ -z "$rule" ] && continue

      # Check if supported
      if grep -qxF "$rule" "$SUPPORTED_RULES_FILE"; then
        echo "--rules $rule" >> "$TEMP_OUTPUT"
      else
        echo "$rule" >> "$UNSUPPORTED_RULES_FILE"
        echo "Unsupported rule: $rule" >&2
      fi
    done
    IFS="$OLD_IFS"
  # Check if this is an option line (--something value)
  elif echo "$line" | grep -qE '^--[a-z]'; then
    # Translate option names for 0.54.6 compatibility
    translated=$(translate_option_line "$line")

    # Track options marked as unsupported
    if echo "$translated" | grep -q '^--SKIP_UNSUPPORTED'; then
      opt_name=$(echo "$line" | sed 's/^--\([a-zA-Z0-9-]*\).*/\1/')
      echo "--$opt_name" >> "$UNSUPPORTED_OPTIONS_FILE"
      echo "Unsupported option: --$opt_name" >&2
    else
      echo "$translated" >> "$TEMP_OUTPUT"
    fi
  else
    # Pass through other lines
    echo "$line" >> "$TEMP_OUTPUT"
  fi
done < "$COMBINED_FILE"

# Check for unsupported rules and options - FAIL HARD
unsupported_rules=$(wc -l < "$UNSUPPORTED_RULES_FILE" | tr -d ' ')
unsupported_options=$(wc -l < "$UNSUPPORTED_OPTIONS_FILE" | tr -d ' ')

if [ "$unsupported_rules" -gt 0 ] || [ "$unsupported_options" -gt 0 ]; then
  echo ""
  echo "ERROR: Unsupported rules/options for pinned SwiftFormat $("$SWIFTFORMAT" --version):"
  if [ "$unsupported_rules" -gt 0 ]; then
    echo ""
    echo "  Unsupported rules ($unsupported_rules):"
    cat "$UNSUPPORTED_RULES_FILE" | sed 's/^/     /'
  fi
  if [ "$unsupported_options" -gt 0 ]; then
    echo ""
    echo "  Unsupported options ($unsupported_options):"
    cat "$UNSUPPORTED_OPTIONS_FILE" | sed 's/^/     /'
  fi
  echo ""
  echo "Action required: Remove these from .swiftformat or .swiftformat.airbnb,"
  echo "or update to a newer SwiftFormat version that supports them."
  rm -f "$OUTPUT"
  exit 1
fi

# Move temp to final
mv "$TEMP_OUTPUT" "$OUTPUT"

# Validate generated config against actual SwiftFormat
echo ""
echo "Validating generated config..."
validation=$("$SWIFTFORMAT" --lint --config "$OUTPUT" --dryrun "$REPO_ROOT/Dispatch" 2>&1 || true)

if echo "$validation" | grep -qiE "unknown (rule|option)"; then
  echo ""
  echo "Generated .swiftformat.ci contains unsupported rules/options:"
  echo "$validation" | grep -iE "unknown (rule|option)"
  echo ""
  echo "You must manually fix these in .swiftformat.airbnb or .swiftformat"
  rm -f "$OUTPUT"
  exit 1
fi

echo "Generated $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. Review the generated config"
echo "  2. Commit it: git add .swiftformat.ci && git commit -m 'Add CI-compatible SwiftFormat config'"
