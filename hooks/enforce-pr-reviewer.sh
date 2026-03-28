#!/bin/bash
# Block PR review Agent calls that don't use gh-pm:pr-reviewer

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""')

# Best-effort keyword detection for PR review agent calls.
# This is heuristic — it matches common phrasings but cannot catch all ways
# a PR review might be described. The hook errs on the side of catching
# obvious cases rather than attempting to match every possible phrasing.
COMBINED="$PROMPT $DESCRIPTION"
IS_PR_REVIEW=false

if echo "$COMBINED" | grep -qiE '(pull request|PR) review|review (the |this )?(pull request|PR)|pr-review'; then
  IS_PR_REVIEW=true
fi

if [ "$IS_PR_REVIEW" = false ]; then
  exit 0
fi

# If it's a PR review but not using the correct subagent type, block
if [ "$SUBAGENT_TYPE" != "gh-pm:pr-reviewer" ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "PR reviews MUST use subagent_type: gh-pm:pr-reviewer."
  }
}
EOF
fi
