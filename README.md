# trackness-agents

Claude Code plugin providing project management workflows, enforcement hooks, and a PR reviewer agent. Installed as a marketplace plugin — applies to all repos where enabled.

## Install

```bash
claude plugin install trackness-agents@claude-agents
```

This registers the marketplace from `trackness/claude-agents` on GitHub and installs the plugin.

## What's Included

### Agent

| Agent | Purpose |
|-------|---------|
| `pr-reviewer` | Comprehensive PR review covering architecture, security, performance, error handling, testing, and readability |

### Skills

| Skill | Purpose |
|-------|---------|
| `/setup-project` | Bootstrap a new repo with GitHub Project, labels, `.claude/project.json`, and starter CLAUDE.md |
| `/task <n>` | Implement a GitHub Issue end-to-end: find, branch, plan, build, verify, ship |
| `/ship` | Commit, PR, review, and merge the current branch |
| `/audit` | 11-dimension codebase gap analysis, generates GitHub Issues |
| `/promote <n>` | Promote a Backlog issue to Ready with full spec via research and brainstorming |

All skills except `/setup-project` require `.claude/project.json` to exist (created by `/setup-project`).

### Hooks

Enforcement hooks that block tool calls mechanically. Claude cannot bypass these.

| Hook | Blocks | Matcher |
|------|--------|---------|
| `no-commit-main.sh` | `git commit` on main/master (allows `--amend`) | Bash |
| `no-hook-bypass.sh` | `--no-verify` on any git command | Bash |
| `doc-staleness-check.sh` | `gh pr create` when substantive changes lack doc updates | Bash |
| `enforce-agent-model.sh` | Agent calls with `model: "haiku"` | Agent |
| `enforce-pr-reviewer.sh` | PR review agents that aren't `trackness-agents:pr-reviewer` | Agent |
| `enforce-memory-approval.sh` | Prompts for approval on writes to memory directory | Write |

## Project Configuration

Skills read project-specific IDs from `.claude/project.json` in each repo. This file is created by `/setup-project` and contains:

- GitHub owner, repo name, repository node ID
- GitHub Project number, node ID, all field and option IDs
- Test command (auto-detected)
- Label list

## Dependencies

System tools (must be installed):
- `gh` — GitHub CLI
- `jq` — JSON processing
- `task` — go-task runner (checked by `/setup-project` in consumer repos)
- `lefthook` — pre-commit hook manager (checked by `/setup-project` in consumer repos)

Claude Code plugins (must be enabled):
- `superpowers-extended-cc` — implementation skills (TDD, planning, debugging, verification)

## Structure

```
trackness-agents/
│
├── .claude-plugin/
│   ├── plugin.json                      # Plugin manifest (name, version)
│   └── marketplace.json                 # Marketplace definition
│
├── agents/
│   └── pr-reviewer.md                   # PR review agent prompt
│
├── hooks/
│   ├── hooks.json                       # Hook configuration (matchers + script paths)
│   ├── no-commit-main.sh               # Block commits to main (allow amend)
│   ├── no-hook-bypass.sh               # Block --no-verify
│   ├── doc-staleness-check.sh           # Block PRs without doc updates
│   ├── enforce-agent-model.sh           # Block haiku subagents
│   ├── enforce-pr-reviewer.sh           # Block wrong PR reviewer
│   └── enforce-memory-approval.sh       # Block unapproved memory writes
│
└── skills/
    ├── setup-project/
    │   ├── SKILL.md                     # Bootstrap a new repo
    │   ├── queries/
    │   │   ├── update-status-field.graphql
    │   │   ├── create-priority-field.graphql
    │   │   ├── create-effort-field.graphql
    │   │   ├── create-type-field.graphql
    │   │   └── link-project-to-repo.graphql
    │   └── templates/
    │       ├── CLAUDE.md                # Starter CLAUDE.md for new repos
    │       ├── project.json             # .claude/project.json schema
    │       └── issue-body.md            # Standard issue body format
    │
    ├── task/
    │   ├── SKILL.md                     # Implement a GitHub Issue end-to-end
    │   └── queries/
    │       ├── combined-issue-query.graphql
    │       └── create-linked-branch.graphql
    │
    ├── ship/
    │   └── SKILL.md                     # Commit, PR, review, merge
    │
    ├── audit/
    │   ├── SKILL.md                     # 11-dimension codebase gap analysis
    │   ├── queries/
    │   │   └── add-blocked-by.graphql
    │   └── templates/
    │       └── issue-body.md            # Standard issue body format
    │
    └── promote/
        ├── SKILL.md                     # Promote backlog to ready
        ├── queries/
        │   ├── add-blocked-by.graphql
        │   └── add-sub-issue.graphql
        └── templates/
            └── issue-body.md            # Standard issue body format
```

## Workflows

### Issue Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Backlog: /audit creates idea
    Backlog --> Ready: /promote specs it out
    Ready --> InProgress: /task picks it up
    InProgress --> Done: /ship merges it
    InProgress --> Ready: Abandoned
    Backlog --> WontDo: Rejected
    Ready --> WontDo: Rejected
```

### /task Flow

```mermaid
flowchart TD
    A["/task n"] --> B[Read project.json]
    B --> C[Find issue on board]
    C --> D{Dependencies satisfied?}
    D -- No --> E[Stop: implement prerequisite]
    D -- Yes --> F[Create branch + set In Progress]
    F --> G{Effort?}
    G -- Medium/High/Highest --> H[Plan via writing-plans]
    G -- Trivial/Low --> I[Skip planning]
    H --> J[Implement via TDD]
    I --> J
    J --> K[Verify against acceptance criteria]
    K --> L[Documentation check]
    L --> M["/ship"]
```

### /ship Flow

```mermaid
flowchart TD
    A["/ship"] --> B{On main?}
    B -- Yes --> C[STOP: create branch first]
    B -- No --> D[Run tests]
    D -- Fail --> E[Debug + fix]
    E --> D
    D -- Pass --> F[Documentation gate]
    F --> G[Clean stale artifacts]
    G --> H[Push + create PR]
    H --> I[pr-reviewer reviews]
    I --> J{Verdict?}
    J -- APPROVE --> K{Zero findings?}
    K -- Yes --> L[Merge]
    K -- No --> N
    J -- APPROVE WITH COMMENTS --> N[Fix all findings]
    J -- REQUEST CHANGES --> N
    J -- REJECT --> N
    N --> D
    L --> O[Set project status: Done]
```

### /promote Flow

```mermaid
flowchart TD
    A["/promote n"] --> B[Fetch backlog issue]
    B --> C[Research: read code, find related issues]
    C --> D[Brainstorm via superpowers skill]
    D --> E[Draft full spec]
    E --> F[Present to user for review]
    F --> G{Approved?}
    G -- No --> E
    G -- Yes --> H{Highest effort?}
    H -- No --> I[Update issue body + set Ready]
    H -- Yes --> J[Break into sub-issues]
    J --> I
```

### /audit Flow

```mermaid
flowchart TD
    A["/audit"] --> B[Read CLAUDE.md + all project items]
    B --> C[Read entire codebase]
    C --> D[11-dimension gap analysis]
    D --> E[Cross-reference existing issues]
    E --> F[Draft findings: Ready or Backlog]
    F --> G[Present to user]
    G --> H{Per-item approval}
    H -- Approved --> I[Create issue + add to project]
    H -- Rejected --> J[Skip]
    I --> H
    J --> H
```

### Hook Enforcement

```mermaid
flowchart LR
    A[Claude calls tool] --> B{PreToolUse hooks}
    B --> C{Match?}
    C -- No --> D[Tool executes]
    C -- Yes --> E[Hook script runs]
    E --> F{Decision}
    F -- allow --> D
    F -- deny --> G[Tool blocked]
    G --> H[Reason sent to Claude]
    H --> I[Claude adjusts approach]
```

## Versioning

Bump the version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` before pushing changes. Consumers pick up updates via `claude plugin update trackness-agents@claude-agents`.
