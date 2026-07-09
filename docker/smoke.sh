#!/bin/bash
# Tier A assertions: run inside the container after install.sh.
# Verifies the install WIRING (files + settings.json) that the unit suites
# can't see, then replays every vector against the installed artifacts.
set -uo pipefail

H="$HOME/.claude/hooks"
S="$HOME/.claude/settings.json"
fail=0

echo "== wiring: installed files =="
for f in write-guard.py block-git-push.sh identity-guard.sh commit-attribution-guard.sh; do
  if [ -f "$H/$f" ]; then echo "  ok  $f"; else echo "  MISSING  $f"; fail=1; fi
done
for d in write-policy rewriters; do
  if [ -d "$H/$d" ]; then echo "  ok  $d/"; else echo "  MISSING  $d/"; fail=1; fi
done

echo "== wiring: settings.json PreToolUse block =="
if jq -e '[.hooks.PreToolUse[]?.hooks[]?.command // "" | test("write-guard\\.py")] | any' "$S" >/dev/null; then
  echo "  ok  write-guard wired into PreToolUse"
else
  echo "  MISSING  write-guard not in settings.json"; fail=1
fi

echo "== replay: write-policy vectors against INSTALLED dispatcher =="
if TVS_WRITE_GUARD="$H/write-guard.py" python3 /src/tests/write-policy.test.py >/tmp/wp.out 2>&1; then
  tail -1 /tmp/wp.out; else tail -1 /tmp/wp.out; fail=1; fi

echo "== replay: git-push vectors against INSTALLED hook =="
if TVS_GIT_PUSH_HOOK="$H/block-git-push.sh" bash /src/tests/git-push.test.sh >/tmp/gp.out 2>&1; then
  tail -1 /tmp/gp.out; else tail -1 /tmp/gp.out; fail=1; fi

echo "----"
[ "$fail" -eq 0 ] && echo "SMOKE: PASS" || echo "SMOKE: FAIL"
exit $fail
