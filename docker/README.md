# Container tests

Two tiers. Run from the repo root.

## Tier A — deterministic install + replay (no API key)

Proves `install.sh` wiring engages: files land in `~/.claude/hooks`, the
`settings.json` PreToolUse block is merged, and every vector still denies/allows
correctly when driven through the **installed** artifacts (not just the repo copy).

```sh
docker build -f docker/Dockerfile.smoke -t tvs-shield-smoke .
docker run --rm tvs-shield-smoke
# → SMOKE: PASS
```

CI-safe and fast. This is the gate.

## Tier C — live LLM smoke (needs API key)

Drives a real headless Claude Code that is asked to `git push`, and checks the
guard blocked it. Non-deterministic and costs tokens — a manual smoke / demo,
not a CI gate.

```sh
docker build -f docker/Dockerfile.live -t tvs-shield-live .
docker run --rm -e ANTHROPIC_API_KEY=sk-ant-... tvs-shield-live
# → LIVE SMOKE: PASS — guard blocked the push
```

Without the key it prints `SKIP`. A single INCONCLUSIVE = re-run (the model may
rephrase or refuse); the deterministic proof is Tier A.

## Per-agent matrix

`docker/run-matrix.sh` builds and runs one leg per agent and prints a PASS/FAIL table:

```sh
bash docker/run-matrix.sh
# claude PASS  opencode PASS  codex PASS
```

It exits non-zero (with a clear message, no build attempted) if `docker` isn't on PATH.

- **claude** (`Dockerfile.smoke`) — the Tier A leg above: install wiring +
  write-policy/git-push/full-chain vector replay against the *installed* artifacts.
- **opencode** (`Dockerfile.opencode`) — installs the opencode JS plugin via
  `install.sh`, then drives the shared `bridges/guard-check.mjs` bridge in-process
  against the installed `guard-all.sh` chain.
  - **Caveat: IN-PROCESS SIMULATION.** opencode itself is not installed or run in
    this image — its own plugin loader/`tool.execute.before` wiring is never
    exercised. This proves the installed plugin files and the guard chain agree on
    decisions when driven directly by Node, not that opencode's runtime calls the
    plugin correctly.
  - A second leg reruns with `python3` stripped from `PATH` and asserts identity
    still blocks a bad-email commit (write-policy legitimately fails *open*
    without python3 — see `guards/guard-all.sh` degraded mode — so only the
    identity assertion is replayed here, not the full vector set).
- **codex** (`Dockerfile.codex`) — codex has **no hook API**, so its only coverage
  from this shield is the global git hook (`core.hooksPath`) install.sh wires up
  for every git tool on the machine. The smoke sets a TVS-org remote and a
  personal gmail `user.email`, runs a real `git commit`, and asserts the hook
  blocks it (nonzero exit). If codex ever ships a hook API, add a native leg the
  way `Dockerfile.opencode` does — until then this is codex's sole coverage.

## Notes

- All legs install from the local tree via `TVS_SHIELD_REPO=/src` (install.sh
  honors that env override), so they test committed HEAD — commit before building.
