# Agent Execution Logs

This directory contains logs from agent executions for system improvement.

## What to Log

Agents should write execution logs here when:
- Completing a feature (summary of decisions made)
- Context7 queries and results
- Verification outcomes (PASS/BLOCKED/N/A)
- Debugging sessions (root cause analysis)

## Log Format

```
YYYY-MM-DD-<feature-slug>.log
```

Example: `2024-01-17-enforce-context7.log`

## Log Structure

```
# Agent Execution Log
Feature: <feature name>
Date: <ISO date>
Agents: <list of agents invoked>

## Context7 Queries
| Library | Query | Result Summary |
|---------|-------|----------------|

## Decisions Made
- <decision 1>
- <decision 2>

## Verification Results
- Build: PASS/FAIL
- Tests: PASS/FAIL
- Context7: PASS/BLOCKED/N/A
- Jobs Critique: SHIP YES/NO/N/A

## Learnings
- <insight for system improvement>
```

## Why Track Logs

These logs help improve the agent system by:
1. Identifying patterns in Context7 usage
2. Tracking common verification failures
3. Building a knowledge base of decisions
4. Debugging agent coordination issues
