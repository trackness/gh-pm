#!/bin/bash
# Block direct writes to memory directory without user approval

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if echo "$FILE_PATH" | grep -qE '\.claude/projects/[^/]+/memory/'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Memory write detected. Review the proposed content before allowing."
  }
}
EOF
fi
