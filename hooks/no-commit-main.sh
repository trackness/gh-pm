#!/bin/bash
# Block git commit on main/master (but allow --amend)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only care about git commit commands
echo "$COMMAND" | grep -q 'git commit' || exit 0

# Allow git commit --amend
echo "$COMMAND" | grep -q '\-\-amend' && exit 0

# Check current branch
BRANCH=$(cd "$CWD" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Cannot commit directly to main. Create a feature branch first."
  }
}
EOF
fi
