# tvs-agent-shield

Safety guards for AI coding agents that prevent destructive, accidental, or
policy-violating commands before they run — and enforce that commits to TVS org repos
carry a company email. Works across Claude Code, CommandCode, opencode, Kilo Code, Cline,
pi, and hermes, with a global git hook as the universal backstop.

## Why

AI coding agents are powerful — which means they can accidentally push to production,
delete Slack messages, run `kubectl delete`, or commit to a company repo under a personal
email. These guards add a layer that blocks dangerous commands and enforces commit identity.

## Agent coverage

The git layer (`guards/git-hooks/_dispatch`, a global `core.hooksPath` hook) catches every agent
because they all shell out to `git`. On top of that, each agent gets a native pre-execution
guard where its hook API allows one:

| Agent | Native pre-exec guard | Mechanism |
|-------|----------------------|-----------|
| Claude Code | `identity-guard.sh` | PreToolUse, JSON stdin, exit-2 block |
| CommandCode | `identity-guard.sh` | PreToolUse (same contract as Claude) |
| opencode | `adapters/opencode/plugin.js` | `tool.execute.before`, throws to block |
| Kilo Code | `adapters/kilocode/plugin.js` | `tool.execute.before`, throws to block |
| pi | `adapters/pi/guard.mjs` | `tool_call` event, `{block:true}` |
| hermes | `adapters/hermes/` | `pre_tool_call` plugin, `{"action":"block"}` |
| Cline (CLI) | `adapters/cline/plugin.mjs` | `beforeTool` plugin (shell wiring best-effort) |
| Cline (VSCode) | — none available — | relies solely on the git layer |

The JS/Python plugins shell out to the same `identity-guard.sh`, so there is one source of
truth for the policy. The git `pre-push` hook owns push enforcement for all agents.

## Hooks

| File | What it guards |
|------|---------------|
| `block-git-push.sh` | Blocks all `git push` — forces you to push manually |
| `commit-attribution-guard.py` | Blocks commits containing AI co-author attribution (Co-Authored-By: Claude) |
| `identity-guard.sh` | Blocks Claude from committing to a TVS org repo under a non-company email |
| `guards/git-hooks/_dispatch` | Global git hook — enforces a company email on TVS org repos for **all** git tooling (manual git, any AI agent), not just Claude |
| `doctl-guard.py` | Blocks all DigitalOcean CLI (`doctl`) commands — must be run manually |
| `kubectl-guard.py` | Blocks destructive `kubectl` commands (delete, apply, scale, exec, etc.) — read-only verbs pass through |
| `write-guard.py` | Dispatcher over per-CLI checkers in `core/write-policy/` — blocks (or `ask`s) destructive ops across 14 CLIs: slackcli, gogcli, acli, gh, gcloud, psql/mysql, aws, docker, heroku, vercel, helm, supabase, ansible, rsync |
| `rtk-rewrite.sh` | Transparently rewrites raw commands to their `rtk` equivalents when available |

Both dispatchers are **drop-in plugin** based: adding a tool means dropping one file in `core/write-policy/` (a `check(cmd)` + `ORDER = N`) or `rewriters/` (a `rewrite_<tool>()` + `register_rewriter N rewrite_<tool>`). The dispatchers auto-discover and run plugins in `ORDER` priority — no dispatcher edits.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/omartuhintvs/tvs-agent-shield/main/install.sh | bash
```

The script:
- Installs the global git hook (`core.hooksPath`) — the universal backstop for every agent
- Detects which agents are installed and wires each one's native guard
- Copies the shared `identity-guard.sh` to `~/.config/tvs-agent-shield/`
- Merges Claude/CommandCode settings (backs up first; never wipes your existing hooks)
- Requires `jq` for auto-merging settings — falls back to manual instructions if not found

### Manual

```bash
# Install the shared core + guards + bridges to the canonical location
mkdir -p ~/.config/tvs-agent-shield
cp -R core guards bridges ~/.config/tvs-agent-shield/

# Copy hooks (identity-guard.sh sources core/policy.sh from
# ~/.config/tvs-agent-shield at runtime via TVS_SHIELD_HOME, so core/ only
# needs to exist there, not in ~/.claude/hooks)
mkdir -p ~/.claude/hooks
cp guards/identity-guard.sh *.py *.sh ~/.claude/hooks/
cp guards/write-guard.py ~/.claude/hooks/
cp -R core/write-policy rewriters ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Add to ~/.claude/settings.json
```

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "python3 $HOME/.claude/hooks/write-guard.py", "statusMessage": "Checking command safety..." },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/doctl-guard.py", "statusMessage": "Checking doctl guardrail..." },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/kubectl-guard.py", "statusMessage": "Checking kubectl guardrail..." },
          { "type": "command", "command": "python3 $HOME/.claude/hooks/commit-attribution-guard.py", "statusMessage": "Checking commit attribution..." },
          { "type": "command", "command": "$HOME/.claude/hooks/block-git-push.sh", "statusMessage": "Checking git push..." },
          { "type": "command", "command": "$HOME/.claude/hooks/identity-guard.sh", "statusMessage": "Checking commit identity..." }
        ]
      }
    ]
  }
}
```

### Verify

Restart Claude Code, then test:

```bash
# Should be blocked:
doctl compute droplet list

# Should be allowed (read-only):
kubectl get pods
```

> **RTK rewrite hook** (`rtk-rewrite.sh`) is optional — only useful if you use the `rtk` CLI tool.

## TVS commit identity enforcement

Two layers keep personal emails off company history. A repo is treated as a **TVS repo**
when a remote URL is in the `technovativesolutions` or `digiprodpass` GitHub org. On those
repos the commit email must end in `@technovativesolutions.co.uk` or `@digiprodpass.com`.
Every other repo is untouched.

- **`identity-guard.sh`** (Claude PreToolUse) — blocks Claude's own `git commit` when the
  effective or injected email is not a company address.
- **`guards/git-hooks/_dispatch`** (global `core.hooksPath`) — a `pre-commit` + `pre-push` guard
  that catches everything the Claude layer can't: manual `git`, other AI agents, `--amend`,
  rebase, cherry-pick. `pre-push` fails **closed** — if it can't enumerate outgoing commits
  it refuses the push.

Set your company identity once:

```bash
git config --global user.email you@technovativesolutions.co.uk
```

By default only the **committer** (the person committing) must be a company address, so
external or rebased foreign-authored commits don't false-block. To also require the
**author** on a given repo:

```bash
git config hooks.requireWorkAuthor true
```

**Limits:** client-side hooks are bypassable (`git push --no-verify`,
`git -c core.hooksPath= …`). This stops accidents, not a determined bypass. Repos that set
their own local `core.hooksPath` (husky, lefthook) shadow the global guard — identity there
relies on your global `user.email`.

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
