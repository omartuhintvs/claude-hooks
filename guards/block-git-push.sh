#!/bin/bash

# Block git push operations globally
# This hook runs before any Bash command execution in Claude Code

# Read hook input from stdin (JSON)
input=$(cat)

# Extract the command from the JSON input
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Match `git ... push` within a single shell segment, so flag-bearing forms
# like `git -C /repo push` and `git --git-dir=x push` are caught too. `push`
# must be a bare subcommand (space/end after it), so `git config push.default`
# is left alone. Mirrors the segment-aware style of core/policy.sh.
if echo "$command" | grep -qE '\bgit\b[^|&;]*\bpush([[:space:]]|$)'; then
  # Exit code 2 blocks the tool call and shows the error to Claude
  echo "ERROR: Git push operations are blocked by global policy. Please push manually if needed." >&2
  exit 2
fi

# Allow all other commands
exit 0
