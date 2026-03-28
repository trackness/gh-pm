#!/bin/bash
# Block gh pr create when substantive changes exist but no docs were updated

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only care about gh pr create
echo "$COMMAND" | grep -q 'gh pr create' || exit 0

cd "$CWD" 2>/dev/null || exit 0

# Detect the default branch
BASE_BRANCH=""
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -n "$BASE_BRANCH" ]; then
  BASE_BRANCH="origin/$BASE_BRANCH"
else
  BASE_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
  if [ -n "$BASE_BRANCH" ]; then
    BASE_BRANCH="origin/$BASE_BRANCH"
  fi
fi

# Fall back to main/master if detection fails
if [ -z "$BASE_BRANCH" ]; then
  BASE_BRANCH="origin/main"
  git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1 || BASE_BRANCH="origin/master"
  git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1 || exit 0
fi

DIFF_OUTPUT=$(git diff "$BASE_BRANCH"...HEAD --name-status 2>/dev/null)

# Check for substantive changes: any non-test file added, deleted, or modified
HAS_SUBSTANTIVE=false

# Test file patterns across supported stacks:
# JS/TS: test/, spec/, __tests__/, *.test.*, *.spec.*
# Go: _test.go
# Python: test_*.py, *_test.py, tests/, conftest.py
# Rust: tests/ (already caught by test pattern)
TEST_PATTERN='(/test/|/spec/|/__tests__/|_test\.|test_|\.test\.|\.spec\.|/conftest\.)'

# Added or modified files (excluding tests and doc files)
if echo "$DIFF_OUTPUT" | grep -E '^[AM]\s' | grep -vE "(${TEST_PATTERN}|CLAUDE\.md|README|docs/)" | grep -q .; then
  HAS_SUBSTANTIVE=true
fi

# Deleted files
if echo "$DIFF_OUTPUT" | grep -qE '^D\s'; then
  HAS_SUBSTANTIVE=true
fi

# Package/dependency file changes
if echo "$DIFF_OUTPUT" | grep -qE 'package\.json'; then
  HAS_SUBSTANTIVE=true
fi

# Config file changes across supported stacks:
# JS/TS: vite.config, tsconfig, biome.json
# Go: go.mod, go.sum
# Rust: Cargo.toml, Cargo.lock
# Python: pyproject.toml, setup.py, setup.cfg, requirements*.txt
# Docker: Dockerfile, docker-compose
# Task runner: Taskfile.yml, Taskfile.yaml
CONFIG_PATTERN='(vite\.config|tsconfig|biome\.json|Dockerfile|docker-compose|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock|pyproject\.toml|setup\.py|setup\.cfg|requirements.*\.txt|Taskfile\.ya?ml)'

if echo "$DIFF_OUTPUT" | grep -qE "$CONFIG_PATTERN"; then
  HAS_SUBSTANTIVE=true
fi

# If no substantive changes, allow
if [ "$HAS_SUBSTANTIVE" = false ]; then
  exit 0
fi

# Check if any doc files were modified
if echo "$DIFF_OUTPUT" | grep -qE '(CLAUDE\.md|README|\.claude/commands/|\.claude/agents/|docs/)'; then
  exit 0
fi

# Substantive changes with no doc updates — block
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "This branch has substantive changes but no documentation updates. Review all project docs for staleness before creating the PR."
  }
}
EOF
