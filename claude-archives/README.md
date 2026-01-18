# Claude Configuration Archives

This directory contains timestamped snapshots of the Claude Code agent system configuration.

## Purpose

Archives preserve the state of the agent system at specific points in time, allowing:
- Rollback to previous configurations
- Comparison of rule changes over time
- Documentation of system evolution

## Structure

Each archive is stored in a timestamped subdirectory:

```
claude-archives/
├── README.md
└── YYYY-MM-DD_HH-MM-SS/
    ├── .claude/
    │   ├── contracts/
    │   ├── debt/
    │   ├── rules/
    │   └── skills/
    └── CLAUDE.md
```

## Creating an Archive

Run the archive script from the repo root:

```bash
./scripts/archive_claude_config.sh
```

This creates a new timestamped folder with a complete copy of the current configuration.

## Contents

Each archive includes:
- `.claude/` - Agent rules, contracts, skills, and debt tracking
- `CLAUDE.md` - Main project instructions for Claude Code
