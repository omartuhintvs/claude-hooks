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
because they all shell out to `git`. On top of that, every hook-capable agent runs the **full
block-guard chain** via one entry point, `guards/guard-all.sh` — the write-policy driver
(`write-guard.py` over `core/write-policy/*.py`, incl. doctl/kubectl/commit-attribution) plus
`identity-guard.sh` plus `block-git-push.sh` — resolved to a single decision (`deny > ask > allow`):

| Agent | Native pre-exec guard | Mechanism |
|-------|----------------------|-----------|
| Claude Code | `guard-all.sh` | PreToolUse, JSON stdin; `ask` honored |
| CommandCode | `guard-all.sh --ask-block` | PreToolUse, exit-code only; `ask → block` |
| opencode | `adapters/opencode/plugin.js` | `tool.execute.before` → `guard-check.mjs` bridge, throws |
| Kilo Code | `adapters/kilocode/plugin.js` | `tool.execute.before` → bridge, throws |
| pi | `adapters/pi/guard.mjs` | `tool_call` event → bridge, `{block:true}` |
| hermes | `adapters/hermes/` | `pre_tool_call` → `guard-all.sh`, `{"action":"block"}` |
| Cline (CLI) | `adapters/cline/plugin.mjs` | `beforeTool` → bridge (shell wiring best-effort) |
| Cline (VSCode) | — none available — | relies solely on the git layer |
| Codex | — no hook API — | relies solely on the git layer (commit identity) |

All agents run the same chain, so there is one source of truth for the policy.

Beyond blocking, `guards/rtk-rewrite.sh` transparently rewrites raw commands to their `rtk`
equivalents when the `rtk` CLI is present (see `guards/rewriters/*.sh`). This runs on Claude
Code as a second PreToolUse hook, and on the JS adapters (opencode, Kilo Code) and hermes via
the `bridges/rewrite-check.mjs` bridge, which mutate the outgoing command in-process after the
block chain allows it. pi and Cline (CLI) have no confirmed in-process API for mutating the
command their host executes, so rewriting is a no-op there (blocks still apply); hermes's
`scan()` hook return contract likewise has no confirmed mutation field, so its rewrite call is
also a no-op today.

**Behavioral delta.** Only Claude Code has an interactive `ask` channel; every other agent
maps `ask → block` with a "run this manually" reason (safe — never fail-open). **Fail policy**:
the write-policy driver fails **open** with a stderr warning if it crashes or `python3` is
absent (convenience guard); `identity-guard.sh` and `block-git-push.sh` fail **closed** for
commit-ish / push commands respectively (core mission). `block-git-push.sh` now blocks pushes
on every agent, not just Claude — an accident guard, not configurable.

## Hooks

| File | What it guards |
|------|---------------|
| `guards/guard-all.sh` | Unified chain — runs `write-guard.py` + `identity-guard.sh` + `block-git-push.sh`, one decision (`deny > ask > allow`). The single hook every agent wires to |
| `guards/block-git-push.sh` | Blocks all `git push` — forces you to push manually |
| `guards/identity-guard.sh` | Blocks Claude from committing to a TVS org repo under a non-company email |
| `guards/git-hooks/_dispatch` | Global git hook — enforces a company email on TVS org repos for **all** git tooling (manual git, any AI agent), not just Claude |
| `guards/write-guard.py` | Dispatcher over per-CLI checkers in `core/write-policy/` — blocks (or `ask`s) destructive ops across 16 CLIs incl. slackcli, gogcli, acli, gh, gcloud, psql/mysql, aws, docker, heroku, vercel, helm, supabase, ansible, rsync, **doctl, kubectl** (destructive verbs) plus a **commit-attribution** checker (blocks `Co-Authored-By: Claude`) |
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

# Copy the guard stack beside guard-all.sh so it self-locates its siblings
# (identity-guard.sh sources core/policy.sh at runtime via TVS_SHIELD_HOME).
mkdir -p ~/.claude/hooks
cp guards/guard-all.sh guards/identity-guard.sh guards/block-git-push.sh \
   guards/write-guard.py guards/rtk-rewrite.sh ~/.claude/hooks/
cp -R core/write-policy guards/rewriters ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Add to ~/.claude/settings.json — guard-all blocks, rtk-rewrite (optional) rewrites after.
```

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/guard-all.sh", "statusMessage": "Running TVS guards..." },
          { "type": "command", "command": "$HOME/.claude/hooks/rtk-rewrite.sh", "statusMessage": "Rewriting to rtk..." }
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

`guard-all.sh` runs the whole chain itself and resolves one decision — `deny > ask >
allow`, so a later hard deny is never masked by an earlier ask.

## Customising

Each hook is a standalone Python or Bash script — easy to read and modify:

- To allow a command: add it to the allowlist inside the relevant hook
- To block more commands: add patterns to the blocklist
- To add a new hook: drop a script in `~/.claude/hooks/` and wire it in `settings.json`

## Testing

Guards and rewriters have their own suites under `tests/` (no framework — plain
`python3`/`bash`, each prints `pass=N fail=0`):

```bash
bash    backlog/checks.sh            # the whole gate — every suite below, must be all-green

python3 tests/policy.test.py         # identity policy core (parity with .sh/.mjs)
bash    tests/policy.test.sh
node    tests/policy.test.mjs
python3 tests/write-policy.test.py   # 16 write-guard checkers, data-driven from core/write-vectors.json
bash    tests/git-push.test.sh       # push-block hook
bash    tests/integration.test.sh
bash    tests/guard-all.test.sh      # unified chain: precedence, fail-policy, --ask-block, full vector replay
node    tests/guard-plugin.test.mjs  # JS bridge (guard-check.mjs) block/allow decisions
python3 tests/hermes-guard.test.py   # hermes adapter fail-closed contract
bash    tests/rtk-rewrite.test.sh    # rtk rewriters, JSON-stdin fixtures
node    tests/rewrite-plugin.test.mjs # rtk rewrite bridge
```

Cross-agent install + behavior is proven in containers: `bash docker/run-matrix.sh`
builds and runs the claude / opencode / codex legs and prints a per-agent PASS/FAIL table.

Adding a checker or rewriter plugin: drop the file (see the drop-in note above),
add its cases to `core/write-vectors.json` (checkers) or the rewriter fixtures,
and the suite picks it up — the dispatchers auto-discover, the tests drive them
end-to-end via stdin.

## Requirements

- Claude Code
- Python 3.x (for `.py` hooks)
- Node.js (for `.mjs` parity test — optional)
- `jq` (for `rtk-rewrite.sh` — optional)

## License

MIT
