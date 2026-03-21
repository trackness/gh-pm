# Claude Development Guide — trackness-agents plugin

This is a Claude Code plugin, not a standalone application. It ships agents, hooks, and skills that apply to all repos where the plugin is enabled.

## What This Repo Is

A Claude Code marketplace plugin (`trackness-agents@claude-agents`) containing:

1. **1 agent** — `pr-reviewer` in `agents/`
2. **6 enforcement hooks** — shell scripts in `hooks/`, configured via `hooks/hooks.json`
3. **5 skills** — markdown-driven workflows in `skills/*/SKILL.md`

Consumers install via `claude plugin install trackness-agents@claude-agents`. The plugin is distributed from this GitHub repo as a marketplace.

## How Plugin Components Work

### Agents (`agents/*.md`)
Markdown files with frontmatter (`name`, `description`). Claude Code discovers them automatically. Users invoke with `subagent_type: "trackness-agents:<agent-name>"`.

### Hooks (`hooks/hooks.json` + scripts)
`hooks.json` registers PreToolUse hooks with matchers (Bash, Agent, Write). Each hook runs a shell script that receives tool call JSON on stdin and outputs a deny/allow decision. Exit 0 = allow. JSON with `permissionDecision: "deny"` = block.

Hook scripts must be executable (`chmod +x`). They reference themselves via `${CLAUDE_PLUGIN_ROOT}/hooks/<script>.sh`.

### Skills (`skills/*/SKILL.md`)
Each skill is a directory with a `SKILL.md` containing frontmatter (`name`, `description`) and the full skill prompt. Users invoke with `/trackness-agents:<skill-name>` or Claude invokes automatically based on context.

Skills that interact with GitHub Projects read configuration from `.claude/project.json` in the consumer repo (created by `/setup-project`).

## Structure

```
.claude-plugin/
  plugin.json           Name, version, metadata
  marketplace.json      Marketplace definition (plugins array)
agents/
  pr-reviewer.md        PR review agent
  pr-reviewer-references/
    lang-typescript.md  TypeScript/React/Node review criteria
    lang-go.md          Go review criteria
    lang-rust.md        Rust review criteria
    lang-python.md      Python review criteria
    infra-docker.md     Docker review criteria
    infra-database.md   Database review criteria
hooks/
  hooks.json            Hook registrations (PreToolUse matchers + script paths)
  *.sh                  Hook enforcement scripts
skills/
  setup-project/        Bootstrap new repos
    templates/
      CLAUDE.md          Starter CLAUDE.md template
      issue-body.md      Standard issue body template
  task/                 Implement GitHub Issues
    queries/            GraphQL for issue operations
  ship/                 Commit, PR, review, merge
  audit/                Codebase gap analysis
    templates/issue-body.md
  promote/              Promote backlog issues to ready
    templates/issue-body.md
```

## Development Rules

1. All hook scripts must be executable. After creating or modifying: `chmod +x hooks/*.sh`
2. Hook scripts receive JSON on stdin. Parse with `jq`. Never assume field presence — use `// ""` defaults.
3. Hook scripts must exit 0 for allow, or output deny JSON. Never exit with other codes unless it's a non-blocking error.
4. Test every hook with sample JSON input before committing. Example: `echo '{"tool_input":{"command":"git commit -m test"},"cwd":"/tmp/test"}' | ./hooks/no-commit-main.sh`
5. Skills reference `<project.number>`, `<project.nodeId>`, `<fields.status.id>` etc. as placeholders — these are resolved at runtime from `.claude/project.json` in the consumer repo. Never hardcode GitHub IDs.
6. The `pr-reviewer.md` agent in this repo is the source of truth. Consumer repos (like kidcough) may have a local copy in `.claude/agents/` — keep them in sync.
7. Bump the version in BOTH `plugin.json` and `marketplace.json` before pushing. If versions don't match, consumers may not pick up updates.

## Versioning

This plugin uses semantic versioning:
- **MAJOR** — breaking changes to skill interfaces, hook behavior, or project.json schema
- **MINOR** — new skills, hooks, or agents; backward-compatible enhancements
- **PATCH** — bug fixes to existing components

Current version is in `.claude-plugin/plugin.json`. Must match `.claude-plugin/marketplace.json`.

## Testing Changes

1. **Hooks:** Test with piped JSON input:
   ```bash
   echo '{"tool_input":{"command":"git commit -m test"},"cwd":"/tmp"}' | ./hooks/no-commit-main.sh
   ```
   Verify: blocked commands produce deny JSON, allowed commands produce no output.

2. **Skills:** Test by running the skill in a consumer repo. Use `claude --plugin-dir /path/to/claude-agents` for local testing without publishing.

3. **Agent:** Test by running a PR review in a consumer repo with `subagent_type: "trackness-agents:pr-reviewer"`.

## Dependencies

This plugin depends on:
- `superpowers-extended-cc` plugin — skills reference its sub-skills (TDD, writing-plans, brainstorming, verification-before-completion, systematic-debugging, receiving-code-review)
- `gh` CLI — all skills use it for GitHub operations
- `jq` — all hooks use it for JSON parsing

## Consumer Repo Requirements

For the skills to work, each consumer repo needs:
1. `.claude/project.json` — created by `/setup-project`
2. A CLAUDE.md — created by `/setup-project` or manually
3. The `superpowers-extended-cc` plugin enabled

## Marketplace Configuration

This repo IS the marketplace. The marketplace definition in `.claude-plugin/marketplace.json` lists this plugin. Consumers add the marketplace via:
```json
{
  "extraKnownMarketplaces": {
    "claude-agents": {
      "source": {
        "source": "github",
        "repo": "trackness/claude-agents"
      }
    }
  }
}
```

This is configured automatically when installing the plugin.
