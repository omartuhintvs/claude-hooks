#!/bin/bash
# tvs-agent-shield installer.
# Usage: curl -fsSL https://raw.githubusercontent.com/omartuhintvs/tvs-agent-shield/main/install.sh | bash
#
# Installs two layers:
#   1. A GLOBAL git hook (core.hooksPath) that enforces a company email on TVS org repos
#      for ALL git tooling — this is the universal backstop, covers every AI agent.
#   2. Native pre-exec guards for each AI coding agent found on this machine
#      (Claude Code, CommandCode, opencode, Kilo Code, Cline).

set -e

REPO="https://github.com/omartuhintvs/tvs-agent-shield.git"
CANON="$HOME/.config/tvs-agent-shield"          # canonical shared location
GUARD="$CANON/guards/identity-guard.sh"
GIT_HOOKS_DIR="$CANON/guards/git-hooks"
TMP_DIR="$(mktemp -d)"
SRC="$TMP_DIR/tvs-agent-shield"

echo "Installing tvs-agent-shield..."
trap 'rm -rf "$TMP_DIR"' EXIT
git clone --depth 1 "$REPO" "$SRC" --quiet

# --- shared assets ---
mkdir -p "$CANON/core" "$CANON/guards"
cp "$SRC"/core/*.sh "$SRC"/core/*.mjs "$SRC"/core/*.py "$SRC"/core/*.json "$CANON/core/"
cp "$SRC/guards/identity-guard.sh" "$GUARD"; chmod +x "$GUARD"

# --- layer 1: global git hook (universal) ---
mkdir -p "$GIT_HOOKS_DIR"
cp "$SRC/guards/git-hooks/_dispatch" "$GIT_HOOKS_DIR/_dispatch"; chmod +x "$GIT_HOOKS_DIR/_dispatch"
for h in pre-commit pre-push commit-msg prepare-commit-msg post-commit post-checkout \
         post-merge post-rewrite pre-rebase pre-merge-commit applypatch-msg pre-applypatch; do
  ln -sf _dispatch "$GIT_HOOKS_DIR/$h"
done
CURRENT_HP="$(git config --global core.hooksPath 2>/dev/null || true)"
if [ -z "$CURRENT_HP" ]; then
  git config --global core.hooksPath "$GIT_HOOKS_DIR"
  echo "✓ git core.hooksPath -> $GIT_HOOKS_DIR"
elif [ "$CURRENT_HP" = "$GIT_HOOKS_DIR" ]; then
  echo "✓ git core.hooksPath already set"
elif [ "$CURRENT_HP" = "$HOME/.config/tvs-agent-shield/git-hooks" ]; then
  git config --global core.hooksPath "$GIT_HOOKS_DIR"
  echo "✓ git core.hooksPath migrated from old location -> $GIT_HOOKS_DIR"
else
  echo "⚠  global core.hooksPath already set to: $CURRENT_HP — NOT overriding."
  echo "   To enable the git guard, chain $GIT_HOOKS_DIR/_dispatch from your hooks, or:"
  echo "     git config --global core.hooksPath $GIT_HOOKS_DIR"
fi

# --- layer 2: per-agent native guards (only for agents present) ---
# One agent's failure must not abort the rest of the install, so drop -e here.
set +e
have_jq() { command -v jq >/dev/null 2>&1; }

install_js_plugin() {  # $1 = plugin dir, $2 = plugin filename in adapters/<name>/
  local dir="$1" file="$2" agentdir="$3"
  mkdir -p "$dir"
  cp "$SRC/adapters/$agentdir/$file" "$dir/$file"
  cp "$SRC/bridges/identity-check.mjs" "$dir/identity-check.mjs"
  cp "$SRC/core/policy.mjs" "$dir/policy.mjs"
}

# Claude Code
if [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude/hooks"
  cp "$SRC"/*.py "$HOME/.claude/hooks/" 2>/dev/null || true
  cp "$SRC"/*.sh "$HOME/.claude/hooks/" 2>/dev/null || true
  cp "$GUARD" "$HOME/.claude/hooks/identity-guard.sh"
  chmod +x "$HOME/.claude/hooks/"*.sh
  rm -f "$HOME/.claude/hooks/install.sh"
  S="$HOME/.claude/settings.json"; [ -f "$S" ] || { mkdir -p "$(dirname "$S")"; echo '{}' >"$S"; }
  if have_jq; then
    HOOK_JSON='{"matcher":"Bash","hooks":[
      {"type":"command","command":"python3 $HOME/.claude/hooks/slackcli-guard.py"},
      {"type":"command","command":"python3 $HOME/.claude/hooks/doctl-guard.py"},
      {"type":"command","command":"python3 $HOME/.claude/hooks/kubectl-guard.py"},
      {"type":"command","command":"python3 $HOME/.claude/hooks/commit-attribution-guard.py"},
      {"type":"command","command":"$HOME/.claude/hooks/identity-guard.sh"},
      {"type":"command","command":"$HOME/.claude/hooks/block-git-push.sh"}]}'
    OURS='slackcli-guard\.py|doctl-guard\.py|kubectl-guard\.py|commit-attribution-guard\.py|identity-guard\.sh|block-git-push\.sh'
    cp "$S" "$S.bak"
    jq --argjson hook "$HOOK_JSON" --arg ours "$OURS" '
      .hooks.PreToolUse = ((.hooks.PreToolUse // [])
        | map(select(([.hooks[]?.command // "" | test($ours)] | any) | not))) + [$hook]
    ' "$S" >"$S.tmp" && mv "$S.tmp" "$S"
    echo "✓ Claude Code guards installed (settings backup: $S.bak)"
  else
    echo "⚠  Claude Code found but jq missing — add the PreToolUse block to $S manually (see README)."
  fi
fi

# CommandCode (same PreToolUse contract as Claude)
if [ -d "$HOME/.commandcode" ] || command -v commandcode >/dev/null 2>&1; then
  S="$HOME/.commandcode/settings.json"; mkdir -p "$(dirname "$S")"; [ -f "$S" ] || echo '{}' >"$S"
  if have_jq; then
    cp "$S" "$S.bak"
    jq --slurpfile add "$SRC/adapters/commandcode/settings.json" '
      .hooks.PreToolUse = ((.hooks.PreToolUse // [])
        | map(select(([.hooks[]?.command // "" | test("identity-guard\\.sh")] | any) | not)))
        + $add[0].hooks.PreToolUse
    ' "$S" >"$S.tmp" && mv "$S.tmp" "$S"
    echo "✓ CommandCode guard installed (backup: $S.bak)"
  else
    echo "⚠  CommandCode found but jq missing — merge adapters/commandcode/settings.json into $S manually."
  fi
fi

# opencode
if [ -d "$HOME/.config/opencode" ]; then
  install_js_plugin "$HOME/.config/opencode/plugin" "plugin.js" "opencode"
  echo "✓ opencode plugin installed"
fi

# Kilo Code
if [ -d "$HOME/.config/kilo" ]; then
  install_js_plugin "$HOME/.config/kilo/plugin" "plugin.js" "kilocode"
  echo "✓ Kilo Code plugin installed"
fi

# Cline (CLI/SDK). The VSCode extension has no scriptable hook — covered by the git layer.
if [ -d "$HOME/.cline" ]; then
  install_js_plugin "$HOME/.cline/plugins" "plugin.mjs" "cline"
  echo "✓ Cline CLI plugin installed (VSCode extension relies on the git layer)"
fi

# pi (earendil-works/pi)
if [ -d "$HOME/.pi" ]; then
  install_js_plugin "$HOME/.pi/agent/extensions" "guard.mjs" "pi"
  echo "✓ pi extension installed"
fi

# hermes (Python plugin)
if [ -d "$HOME/.hermes" ]; then
  d="$HOME/.hermes/plugins/tvs_identity_guard"; mkdir -p "$d"
  cp "$SRC/adapters/hermes/__init__.py" "$SRC/adapters/hermes/plugin.yaml" "$d/"
  cp "$SRC/core/policy.py" "$d/policy.py"
  echo "✓ hermes plugin installed"
fi

echo ""
echo "Set your company identity once:"
echo "  git config --global user.email you@technovativesolutions.co.uk"
echo ""
echo "⚠  Repos with their own local core.hooksPath (husky, lefthook) shadow the global git"
echo "   guard — identity there relies on your global user.email being a company address."
echo ""
echo "Done. Restart your agents for the guards to take effect."
