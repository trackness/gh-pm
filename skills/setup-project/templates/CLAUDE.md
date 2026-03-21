# Claude Development Guide

## Hooks Enforcement

The following rules are enforced by hooks in the trackness-agents plugin. These block tool calls mechanically — they cannot be bypassed.

| Hook | Enforces |
|------|----------|
| `no-commit-main.sh` | No direct commits to main (amend allowed) |
| `no-hook-bypass.sh` | No --no-verify on git commands |
| `enforce-agent-model.sh` | No haiku model on subagents |
| `enforce-memory-approval.sh` | Memory writes require user approval |
| `enforce-pr-reviewer.sh` | PR reviews must use trackness-agents:pr-reviewer |
| `doc-staleness-check.sh` | Substantive changes require doc updates |

---

## Task Management

All development tasks are tracked as GitHub Issues. The GitHub Project board is the single source of truth. Configuration is in `.claude/project.json`.

Query the board: `gh project item-list {number} --owner {owner} --limit 200 --format json`

### Effort Scale

| Value     | Meaning                                             |
|-----------|-----------------------------------------------------|
| Trivial   | Minimal change, near-zero complexity                |
| Low       | Small, well-understood change                       |
| Medium    | Moderate scope, some design decisions               |
| High      | Substantial scope, significant implementation work  |
| Highest   | Very large scope; consider breaking into sub-issues |

> Medium, High, and Highest effort issues require a plan before implementation.

### Priority Scale

| Value    | Meaning                  |
|----------|--------------------------|
| Critical | Must be done immediately |
| High     | Important, do soon       |
| Medium   | Normal priority          |
| Low      | Nice to have             |
| Lowest   | Someday/maybe            |

### Branch Naming

```text
<type>/<short-description>
```

feat/, fix/, chore/, refactor/

### Issue Body Template

Use the standard template from the trackness-agents plugin. All issues created by `/audit`, `/promote`, and `/task` follow this format: Why, Implementation, Files, Testing, Acceptance Criteria.

---

## Pre-commit Hooks

<!-- Configure your lefthook pre-commit hooks and document them here -->

---

## Project Info

**Description:** <!-- What this project does, in one sentence -->

**Tech Stack:** <!-- List languages, frameworks, databases, deployment targets -->

**Structure:** <!-- Key directories and what they contain -->

**Testing:** `{testCommand}`

**Deployment:** <!-- How this project is deployed -->
