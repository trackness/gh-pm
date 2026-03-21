#!/bin/bash
# Block gh pr create when substantive changes exist but no docs were updated

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only care about gh pr create
echo "$COMMAND" | grep -q 'gh pr create' || exit 0

cd "$CWD" 2>/dev/null || exit 0

# Get the diff against main (or master)
BASE_BRANCH="main"
git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1 || BASE_BRANCH="master"
git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1 || exit 0

DIFF_OUTPUT=$(git diff "$BASE_BRANCH"...HEAD --name-status 2>/dev/null)

# Check for substantive changes: any non-test file added, deleted, or modified
HAS_SUBSTANTIVE=false

# Added or modified files (excluding tests and doc files)
if echo "$DIFF_OUTPUT" | grep -E '^[AM]\s' | grep -vE '(test|spec|__tests__|CLAUDE\.md|README|docs/)' | grep -q .; then
  HAS_SUBSTANTIVE=true
fi

# Deleted files
if echo "$DIFF_OUTPUT" | grep -qE '^D\s'; then
  HAS_SUBSTANTIVE=true
fi

# Package.json changes
if echo "$DIFF_OUTPUT" | grep -qE 'package\.json'; then
  HAS_SUBSTANTIVE=true
fi

# Config file changes
if echo "$DIFF_OUTPUT" | grep -qE '(vite\.config|tsconfig|biome\.json|Dockerfile|docker-compose)'; then
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
