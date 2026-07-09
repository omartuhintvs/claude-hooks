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

## Notes

- Both install from the local tree via `TVS_SHIELD_REPO=/src` (install.sh honors
  that env override), so they test committed HEAD — commit before building.
- `opencode` uses a JS plugin, a different contract than Claude's PreToolUse JSON;
  it is not covered here yet (see backlog).
