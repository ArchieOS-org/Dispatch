#!/bin/bash
#
# Install pinned tool versions with SHA256 verification.
# Downloads release binaries from GitHub.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
CHECKSUMS_FILE="$TOOLS_DIR/checksums.txt"

# Pinned versions (match macos-14 runner for CI parity)
# These are deliberately older to match GitHub Actions reality.
# To upgrade: bump versions, update checksums.txt, and regenerate .swiftformat.ci
SWIFTFORMAT_VERSION="0.54.6"
SWIFTLINT_VERSION="0.57.0"

# Archive names (universal binaries)
SWIFTFORMAT_ARCHIVE="swiftformat.zip"
SWIFTLINT_ARCHIVE="portable_swiftlint.zip"

mkdir -p "$TOOLS_DIR"

# Enforce executable permissions on cached binaries
# (macOS permissions can get weird after cache restore)
chmod +x "$TOOLS_DIR/swiftformat" "$TOOLS_DIR/swiftlint" 2>/dev/null || true

#######################################
# Verify SHA256 checksum (MANDATORY)
# Fails if checksums.txt missing or entry not found.
#######################################
verify_checksum() {
  local file="$1"
  local archive_name="$2"

  # Checksums file MUST exist
  if [ ! -f "$CHECKSUMS_FILE" ]; then
    echo "checksums.txt missing at $CHECKSUMS_FILE"
    echo "   This file is required for deterministic builds."
    echo "   Create it with SHA256 hashes for all tool archives."
    return 1
  fi

  # Entry MUST exist (grep for "  archive_name" to match checksum format)
  local expected
  expected=$(grep -F "  $archive_name" "$CHECKSUMS_FILE" 2>/dev/null | awk '{print $1}')

  if [ -z "$expected" ]; then
    echo "No checksum entry for $archive_name"
    echo "   Add entry to $CHECKSUMS_FILE:"
    echo "   <sha256>  $archive_name"
    return 1
  fi

  local actual
  actual=$(shasum -a 256 "$file" | awk '{print $1}')

  if [ "$actual" != "$expected" ]; then
    echo "Checksum mismatch for $archive_name!"
    echo "   Expected: $expected"
    echo "   Actual:   $actual"
    return 1
  fi

  echo "   Checksum verified"
  return 0
}

#######################################
# Download and install a tool
#######################################
install_tool() {
  local name="$1"
  local version="$2"
  local url="$3"
  local archive_name="$4"
  local binary_name="$5"

  local dest="$TOOLS_DIR/$binary_name"

  if [ -x "$dest" ]; then
    local current_version
    if [ "$binary_name" = "swiftformat" ]; then
      current_version=$("$dest" --version 2>/dev/null || echo "unknown")
    else
      current_version=$("$dest" version 2>/dev/null || echo "unknown")
    fi
    echo "$name already installed ($current_version)"
    return 0
  fi

  echo "Installing $name $version..."

  local tmpdir
  tmpdir=$(mktemp -d)
  local archive="$tmpdir/$archive_name"

  # Download
  echo "   Downloading $url"
  if ! curl -fsSL -o "$archive" "$url"; then
    echo "Failed to download $name"
    rm -rf "$tmpdir"
    return 1
  fi

  # Verify checksum
  if ! verify_checksum "$archive" "$archive_name"; then
    rm -rf "$tmpdir"
    return 1
  fi

  # Extract
  echo "   Extracting..."
  unzip -q -o "$archive" -d "$tmpdir"

  # Find binary (portable across BSD/macOS)
  local binary
  binary=$(find "$tmpdir" -type f -name "$binary_name" 2>/dev/null | head -1)

  if [ -z "$binary" ]; then
    echo "Could not find $binary_name in archive"
    echo "   Archive contents:"
    ls -laR "$tmpdir"
    rm -rf "$tmpdir"
    return 1
  fi

  # Install
  cp "$binary" "$dest"
  chmod +x "$dest"

  # Validate binary: must run successfully AND output expected pattern
  # (A broken binary can print dyld errors but still have non-empty output)
  # Uses first-line only + anchored pattern to handle CRLF/multi-line/warnings
  echo "   Validating binary..."
  local toolcheck_file="$tmpdir/toolcheck.out"
  local toolcheck_line="$tmpdir/toolcheck.1"
  local exit_ok=1
  local pattern_ok=1

  if [ "$binary_name" = "swiftformat" ]; then
    "$dest" --version > "$toolcheck_file" 2>&1
    exit_ok=$?
    # First line only, strip CRLF, anchored pattern
    head -n 1 "$toolcheck_file" | tr -d '\r' > "$toolcheck_line"
    grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' "$toolcheck_line"
    pattern_ok=$?
  else
    "$dest" version > "$toolcheck_file" 2>&1
    exit_ok=$?
    # First line only, strip CRLF, anchored pattern
    head -n 1 "$toolcheck_file" | tr -d '\r' > "$toolcheck_line"
    grep -qE '^(SwiftLint version: )?[0-9]+\.[0-9]+\.[0-9]+$' "$toolcheck_line"
    pattern_ok=$?
  fi

  if [ $exit_ok -ne 0 ] || [ $pattern_ok -ne 0 ]; then
    echo "$binary_name failed validation"
    echo "   Exit code: $exit_ok, Pattern match: $pattern_ok"
    echo "   Output:"
    cat "$toolcheck_file" | sed 's/^/   /'
    rm -f "$dest"
    rm -rf "$tmpdir"
    return 1
  fi

  local test_version
  test_version=$(cat "$toolcheck_line")

  # Cleanup
  rm -rf "$tmpdir"

  echo "$name $version installed (verified: $test_version)"
  return 0
}

#######################################
# Main
#######################################
main() {
  echo "Installing pinned tools..."
  echo ""

  local failed=0

  # SwiftFormat
  if ! install_tool "SwiftFormat" "$SWIFTFORMAT_VERSION" \
    "https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/$SWIFTFORMAT_ARCHIVE" \
    "$SWIFTFORMAT_ARCHIVE" \
    "swiftformat"; then
    failed=1
  fi

  echo ""

  # SwiftLint
  if ! install_tool "SwiftLint" "$SWIFTLINT_VERSION" \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/$SWIFTLINT_ARCHIVE" \
    "$SWIFTLINT_ARCHIVE" \
    "swiftlint"; then
    failed=1
  fi

  echo ""

  if [ $failed -eq 1 ]; then
    echo "Some tools failed to install"
    exit 1
  fi

  echo "All tools installed"
  echo ""
  echo "Versions:"
  echo "  SwiftFormat: $("$TOOLS_DIR/swiftformat" --version)"
  echo "  SwiftLint: $("$TOOLS_DIR/swiftlint" version)"
}

main "$@"
