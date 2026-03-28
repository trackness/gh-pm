#!/bin/bash
# Block git commit on the default branch (but allow --amend)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only care about git commit commands
echo "$COMMAND" | grep -q 'git commit' || exit 0

# Allow git commit --amend
echo "$COMMAND" | grep -q '\-\-amend' && exit 0

# Check current branch — fail closed if we can't determine it
if [ -z "$CWD" ]; then
  BRANCH=""
else
  BRANCH=$(cd "$CWD" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

if [ -z "$BRANCH" ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Could not determine current branch. Confirm this commit is safe."
  }
}
EOF
  exit 0
fi

# Detect the default branch
DEFAULT_BRANCH=""
if [ -n "$CWD" ]; then
  DEFAULT_BRANCH=$(cd "$CWD" 2>/dev/null && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH=$(cd "$CWD" 2>/dev/null && gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
  fi
fi

# Fall back to main/master if detection fails
if [ -z "$DEFAULT_BRANCH" ]; then
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    DEFAULT_BRANCH="$BRANCH"
  else
    exit 0
  fi
fi

if [ "$BRANCH" = "$DEFAULT_BRANCH" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Cannot commit directly to ${DEFAULT_BRANCH}. Create a feature branch first."
  }
}
EOF
fi
