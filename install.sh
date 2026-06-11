#!/bin/bash
set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Installing claude-hooks..."

# Create hooks directory
mkdir -p "$HOOKS_DIR"

# Copy hooks
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR"/*.py "$HOOKS_DIR/"
cp "$SCRIPT_DIR"/*.sh "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR"/*.sh
# Don't leave install.sh in hooks dir
rm -f "$HOOKS_DIR/install.sh"

echo "✓ Hooks copied to $HOOKS_DIR"

# Wire into settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
  echo "✓ Created $SETTINGS_FILE"
fi

# Check if jq available for merging
if ! command -v jq &>/dev/null; then
  echo ""
  echo "⚠  jq not found — cannot auto-update settings.json."
  echo "   Add the following to $SETTINGS_FILE manually:"
  echo ""
  cat <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python3 $HOME/.claude/hooks/slackcli-guard.py", "statusMessage": "Checking command safety..." },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/doctl-guard.py", "statusMessage": "Checking doctl guardrail..." },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/kubectl-guard.py", "statusMessage": "Checking kubectl guardrail..." },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/commit-attribution-guard.py", "statusMessage": "Checking commit attribution..." },
          { "type": "command", "command": "$HOME/.claude/hooks/block-git-push.sh", "statusMessage": "Checking git push..." }
        ]
      }
    ]
  }
}
JSON
  exit 0
fi

# Merge hook entries into existing settings.json (replaces any existing Bash PreToolUse matcher)
HOOK_JSON='{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "python3 $HOME/.claude/hooks/slackcli-guard.py", "statusMessage": "Checking command safety..." },
    { "type": "command", "command": "python3 $HOME/.claude/hooks/doctl-guard.py", "statusMessage": "Checking doctl guardrail..." },
    { "type": "command", "command": "python3 $HOME/.claude/hooks/kubectl-guard.py", "statusMessage": "Checking kubectl guardrail..." },
    { "type": "command", "command": "python3 $HOME/.claude/hooks/commit-attribution-guard.py", "statusMessage": "Checking commit attribution..." },
    { "type": "command", "command": "$HOME/.claude/hooks/block-git-push.sh", "statusMessage": "Checking git push..." }
  ]
}'

BACKUP="$SETTINGS_FILE.bak"
cp "$SETTINGS_FILE" "$BACKUP"

jq --argjson hook "$HOOK_JSON" '
  .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(.matcher != "Bash"))) + [$hook]
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "✓ settings.json updated (backup at $BACKUP)"
echo ""
echo "Done. Restart Claude Code for hooks to take effect."
