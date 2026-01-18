#!/bin/bash
#
# archive_claude_config.sh
#
# Archives the Claude Code agent system configuration to a timestamped folder.
# This preserves snapshots of the .claude/ directory and CLAUDE.md file.
#

set -e

# Get the repo root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Create timestamp for the archive folder
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Define paths
ARCHIVE_BASE="$REPO_ROOT/claude-archives"
ARCHIVE_DIR="$ARCHIVE_BASE/$TIMESTAMP"

# Source files to archive
CLAUDE_DIR="$REPO_ROOT/.claude"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

# Validate source files exist
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "Error: .claude/ directory not found at $CLAUDE_DIR"
  exit 1
fi

if [ ! -f "$CLAUDE_MD" ]; then
  echo "Error: CLAUDE.md not found at $CLAUDE_MD"
  exit 1
fi

# Create the archive directory
mkdir -p "$ARCHIVE_DIR"

# Copy .claude directory
cp -R "$CLAUDE_DIR" "$ARCHIVE_DIR/.claude"

# Copy CLAUDE.md
cp "$CLAUDE_MD" "$ARCHIVE_DIR/CLAUDE.md"

# Print confirmation
echo "Claude configuration archived successfully."
echo ""
echo "Archive location: $ARCHIVE_DIR"
echo ""
echo "Contents:"
echo "  - .claude/ (full directory copy)"
echo "  - CLAUDE.md"
echo ""
echo "Timestamp: $TIMESTAMP"
