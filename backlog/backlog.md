# PR-A — block-guards on every hook-capable agent

Unify the guard stack behind one `guards/guard-all.sh` entry point and wire it into
every hook-capable agent, so the full block-guard set (write-policy + identity +
push) runs everywhere — not just Claude. Proven by `backlog/checks.sh` + Docker matrix.

## Gate — `bash backlog/checks.sh`

```
ok   write-policy   pass=137 fail=0
ok   git-push       pass=11 fail=0
ok   policy-sh      pass=25 fail=0
ok   policy-mjs     pass=25 fail=0
ok   policy-py      pass=25 fail=0
ok   integration    pass=25 fail=0
ok   guard-all      pass=153 fail=0   # incl. all 137 write + 11 push vectors replayed THROUGH guard-all
ok   guard-plugin   pass=8 fail=0
CHECKS: PASS
```

`tests/rtk-rewrite.test.sh` is excluded: pre-existing-broken on `main` (10/40, environmental
rtk tooling) and rtk rewriters are PR-B scope.

## Coverage delta — which block-guards fire on which agent

| agent | before | after |
|---|---|---|
| Claude Code | write-policy + identity + push + doctl/kubectl/attribution (6 hooks) | **same set, 1 hook** (guard-all) |
| CommandCode | identity only | **full chain** (guard-all --ask-block; ask→deny, exit-code consumer) |
| opencode / Kilo / Cline / pi | identity only (commit cmds) | **full chain, every bash cmd** (guard-check.mjs bridge; ask→block) |
| hermes | identity only (commit cmds) | **full chain, every bash cmd** (guard-all; ask→block) |
| Codex | git hook only (no hook API) | unchanged — git hook only |
| python3-absent (JS agents) | — | write-policy fail-open + warn; **identity + push still fail-closed** |

## Red→green (opencode, via installed plugin + chain)

- before: `docker rm -f x` on opencode → allowed (identity-only guard ignored it).
- after: `node tests/guard-plugin.test.mjs` drives the bridge → `docker rm` **blocked**; degraded
  (no python3) still blocks a bad-email commit. `pass=8 fail=0`.

## guard-all contract (frozen before implementation)

- Buffers stdin once, replays to each child (stdin is consumed once).
- write-guard.py signals via **stdout JSON** (always exit 0) → guard-all parses it; shell
  guards signal via **exit 2**. Precedence `deny > ask > allow`.
- Fail policy: write-policy fail-**open** (convenience, python3 may be absent); identity +
  push fail-**closed** but only for commit-ish / push-ish commands respectively.
- Dual-signal: JSON on stdout + reason on stderr + exit (deny→2, allow→0, ask→0 default /
  →2 with `--ask-block` for exit-code consumers).
