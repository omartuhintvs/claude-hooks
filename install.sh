#!/bin/bash
# Install claude-hooks directly from GitHub
# Usage: curl -fsSL https://raw.githubusercontent.com/omartuhintvs/claude-hooks/main/install.sh | bash

set -e

REPO="https://github.com/omartuhintvs/claude-hooks.git"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
TMP_DIR="$(mktemp -d)"

echo "Installing claude-hooks..."

# Clone repo to temp dir
git clone --depth 1 "$REPO" "$TMP_DIR/claude-hooks" --quiet

# Copy hooks
mkdir -p "$HOOKS_DIR"
cp "$TMP_DIR/claude-hooks"/*.py "$HOOKS_DIR/"
cp "$TMP_DIR/claude-hooks"/*.sh "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR"/*.sh
rm -f "$HOOKS_DIR/install.sh"
rm -rf "$TMP_DIR"

echo "✓ Hooks installed to $HOOKS_DIR"

# Create settings file if missing
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

if ! command -v jq &>/dev/null; then
  echo ""
  echo "⚠  jq not found — add this to $SETTINGS_FILE manually:"
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

cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
jq --argjson hook "$HOOK_JSON" '
  .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(.matcher != "Bash"))) + [$hook]
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "✓ settings.json updated (backup: $SETTINGS_FILE.bak)"
echo ""
echo "Done. Restart Claude Code for hooks to take effect."
