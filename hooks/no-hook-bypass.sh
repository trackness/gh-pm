#!/bin/bash
# Block --no-verify on git commands

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only care about git commands
echo "$COMMAND" | grep -qE '\bgit (commit|push|merge|rebase|cherry-pick|am|fetch|pull)\b' || exit 0

# Block if --no-verify is present
if echo "$COMMAND" | grep -q '\-\-no-verify'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "--no-verify is forbidden. Fix the hook failure instead of bypassing it."
  }
}
EOF
fi
