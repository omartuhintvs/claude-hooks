# claude-hooks

Safety hooks for [Claude Code](https://claude.ai/code) — guards against destructive or unintended commands.

## Hooks

| File | Guards Against |
|------|---------------|
| `block-git-push.sh` | Force pushes and dangerous git operations |
| `commit-attribution-guard.py` | Unwanted co-author attribution in commits |
| `doctl-guard.py` | Destructive DigitalOcean CLI commands |
| `kubectl-guard.py` | Dangerous Kubernetes operations |
| `slackcli-guard.py` | Accidental Slack messages/deletes |
| `rtk-rewrite.sh` | RTK query rewrites |

## Setup

Copy hooks to `~/.claude/hooks/` and wire them in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python3 $HOME/.claude/hooks/slackcli-guard.py" },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/doctl-guard.py" },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/kubectl-guard.py" },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/commit-attribution-guard.py" }
        ]
      }
    ]
  }
}
```
