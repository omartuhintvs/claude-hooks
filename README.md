# claude-hooks

Production-grade safety hooks for [Claude Code](https://claude.ai/code) that prevent destructive, accidental, or policy-violating commands before they run.

## Why

Claude Code is powerful — which means it can accidentally push to production, delete Slack messages, or run `kubectl delete`. These hooks add a guardrail layer that blocks dangerous commands and requires human confirmation.

## Hooks

| File | What it guards |
|------|---------------|
| `block-git-push.sh` | Blocks all `git push` — forces you to push manually |
| `commit-attribution-guard.py` | Blocks commits containing AI co-author attribution (Co-Authored-By: Claude) |
| `doctl-guard.py` | Blocks all DigitalOcean CLI (`doctl`) commands — must be run manually |
| `kubectl-guard.py` | Blocks destructive `kubectl` commands (delete, apply, scale, exec, etc.) — read-only verbs pass through |
| `slackcli-guard.py` | Blocks destructive operations across 10+ CLIs: slackcli, gh, gcloud, aws, docker, heroku, vercel, helm, supabase, ansible, and more |
| `rtk-rewrite.sh` | Transparently rewrites raw commands to their `rtk` equivalents when available |

## Installation

### 1. Copy hooks

```bash
# Clone the repo
git clone https://github.com/omartuhintvs/claude-hooks.git

# Copy hooks to Claude's hooks directory
mkdir -p ~/.claude/hooks
cp claude-hooks/*.py claude-hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

### 2. Wire into settings

Add to `~/.claude/settings.json` (create if it doesn't exist):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 $HOME/.claude/hooks/slackcli-guard.py",
            "statusMessage": "Checking command safety..."
          },
          {
            "type": "command",
            "command": "python3 $HOME/.claude/hooks/doctl-guard.py",
            "statusMessage": "Checking doctl guardrail..."
          },
          {
            "type": "command",
            "command": "python3 $HOME/.claude/hooks/kubectl-guard.py",
            "statusMessage": "Checking kubectl guardrail..."
          },
          {
            "type": "command",
            "command": "python3 $HOME/.claude/hooks/commit-attribution-guard.py",
            "statusMessage": "Checking commit attribution..."
          },
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/block-git-push.sh",
            "statusMessage": "Checking git push..."
          }
        ]
      }
    ]
  }
}
```

> **RTK rewrite hook** is optional — only useful if you use the `rtk` CLI tool.

### 3. Verify

Start a new Claude Code session and try running a blocked command:

```bash
# Should be blocked:
doctl compute droplet list

# Should be allowed:
kubectl get pods
```

## How hooks work

Each hook reads the Bash command from stdin as JSON:

```json
{ "tool_input": { "command": "kubectl delete pod my-pod" } }
```

Hooks output a JSON decision:
- **Allow**: exit code `0` with `permissionDecision: "allow"`
- **Block**: exit code `2` — stderr message is shown to Claude

Claude Code runs hooks in order. First block wins.

## Customising

Each hook is a standalone Python or Bash script — easy to read and modify:

- To allow a command: add it to the allowlist inside the relevant hook
- To block more commands: add patterns to the blocklist
- To add a new hook: drop a script in `~/.claude/hooks/` and wire it in `settings.json`

## Requirements

- Claude Code
- Python 3.x (for `.py` hooks)
- `jq` (for `rtk-rewrite.sh` — optional)

## License

MIT
