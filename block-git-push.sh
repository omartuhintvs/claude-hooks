#!/bin/bash

# Block git push operations globally
# This hook runs before any Bash command execution in Claude Code

# Read hook input from stdin (JSON)
input=$(cat)

# Extract the command from the JSON input
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Check if the command contains "git push"
if echo "$command" | grep -q "git push"; then
  # Exit code 2 blocks the tool call and shows the error to Claude
  echo "ERROR: Git push operations are blocked by global policy. Please push manually if needed." >&2
  exit 2
fi

# Allow all other commands
exit 0
