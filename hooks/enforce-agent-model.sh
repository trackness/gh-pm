#!/bin/bash
# Block haiku model on Agent tool calls

INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // ""')

if echo "$MODEL" | grep -qi 'haiku'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Never downgrade subagent models. haiku is not allowed."
  }
}
EOF
fi
