#!/bin/bash
# Block PR review Agent calls that don't use trackness-agents:pr-reviewer

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')

# Check if this is a PR/pull review related agent call
COMBINED="$PROMPT $DESCRIPTION"
IS_PR_REVIEW=false

if echo "$COMBINED" | grep -qiE '(pull request|PR) review|review (the |this )?(pull request|PR)|pr-review'; then
  IS_PR_REVIEW=true
fi

if [ "$IS_PR_REVIEW" = false ]; then
  exit 0
fi

# If it's a PR review but not using the correct subagent type, block
if [ "$SUBAGENT_TYPE" != "trackness-agents:pr-reviewer" ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "PR reviews MUST use subagent_type: trackness-agents:pr-reviewer."
  }
}
EOF
fi
