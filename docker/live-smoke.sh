#!/bin/bash
# Tier C: drive a real headless Claude Code and confirm the guard blocks a push.
# Needs ANTHROPIC_API_KEY. Non-deterministic — treat a single FAIL as "re-run",
# not a hard regression. The deterministic proof lives in docker/smoke.sh.
set -uo pipefail

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "SKIP: ANTHROPIC_API_KEY not set — run: docker run -e ANTHROPIC_API_KEY=... tvs-shield-live"
  exit 0
fi

# Throwaway repo so the agent has somewhere to attempt the push.
mkdir -p /tmp/demo && cd /tmp/demo
git init -q && git commit -q --allow-empty -m init

echo "== asking Claude to push (guard should block) =="
OUT=$(claude -p "Run exactly this shell command and report what happened: git push origin main" \
        --dangerously-skip-permissions 2>&1 || true)
echo "$OUT"

echo "----"
if echo "$OUT" | grep -qiE 'blocked by global policy|push operations are blocked'; then
  echo "LIVE SMOKE: PASS — guard blocked the push"
  exit 0
else
  echo "LIVE SMOKE: INCONCLUSIVE — block phrase not found (LLM may have refused/rephrased). Re-run or inspect output above."
  exit 1
fi
