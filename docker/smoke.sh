#!/bin/bash
# Tier A assertions: run inside the container after install.sh.
# Verifies the install WIRING (files + settings.json) that the unit suites
# can't see, then replays every vector against the installed artifacts.
set -uo pipefail

H="$HOME/.claude/hooks"
S="$HOME/.claude/settings.json"
fail=0

echo "== wiring: installed files =="
for f in guard-all.sh write-guard.py block-git-push.sh identity-guard.sh rtk-rewrite.sh; do
  if [ -f "$H/$f" ]; then echo "  ok  $f"; else echo "  MISSING  $f"; fail=1; fi
done
for d in write-policy rewriters; do
  if [ -d "$H/$d" ]; then echo "  ok  $d/"; else echo "  MISSING  $d/"; fail=1; fi
done
if [ -f "$H/write-policy/commit-attribution.py" ]; then
  echo "  ok  write-policy/commit-attribution.py"
else
  echo "  MISSING  write-policy/commit-attribution.py"; fail=1
fi

echo "== wiring: settings.json PreToolUse block =="
if jq -e '[.hooks.PreToolUse[]?.hooks[]?.command // "" | test("guard-all\\.sh")] | any' "$S" >/dev/null; then
  echo "  ok  guard-all wired into PreToolUse"
else
  echo "  MISSING  guard-all not in settings.json"; fail=1
fi
if jq -e '[.hooks.PreToolUse[]?.hooks[]?.command // "" | test("rtk-rewrite\\.sh")] | any' "$S" >/dev/null; then
  echo "  ok  rtk-rewrite wired into PreToolUse"
else
  echo "  MISSING  rtk-rewrite not in settings.json"; fail=1
fi

echo "== replay: write-policy vectors against INSTALLED dispatcher =="
if TVS_WRITE_GUARD="$H/write-guard.py" python3 /src/tests/write-policy.test.py >/tmp/wp.out 2>&1; then
  tail -1 /tmp/wp.out; else tail -1 /tmp/wp.out; fail=1; fi

echo "== replay: git-push vectors against INSTALLED hook =="
if TVS_GIT_PUSH_HOOK="$H/block-git-push.sh" bash /src/tests/git-push.test.sh >/tmp/gp.out 2>&1; then
  tail -1 /tmp/gp.out; else tail -1 /tmp/gp.out; fail=1; fi

echo "== replay: full chain vectors against INSTALLED guard-all.sh =="
if TVS_GUARD_ALL="$H/guard-all.sh" TVS_SHIELD_HOME="$HOME/.config/tvs-agent-shield" \
   TVS_WRITE_GUARD="$H/write-guard.py" TVS_IDENTITY_GUARD="$H/identity-guard.sh" \
   TVS_GIT_PUSH_HOOK="$H/block-git-push.sh" bash /src/tests/guard-all.test.sh >/tmp/ga.out 2>&1; then
  tail -1 /tmp/ga.out; else tail -1 /tmp/ga.out; fail=1; fi

echo "== replay: rtk-rewrite fires against INSTALLED rewriter =="
rw_out="$(printf '%s' '{"tool_input":{"command":"git status"}}' | "$H/rtk-rewrite.sh" 2>/tmp/rw.err)"
rw_rc=$?
if [ "$rw_rc" -ne 0 ]; then
  echo "  FAIL  rtk-rewrite.sh exited $rw_rc"; cat /tmp/rw.err; fail=1
elif command -v rtk >/dev/null 2>&1; then
  rewritten="$(printf '%s' "$rw_out" | jq -r '.hookSpecificOutput.updatedInput.command // empty' 2>/dev/null)"
  if [ "$rewritten" = "rtk git status" ]; then
    echo "  ok  rtk-rewrite rewrote 'git status' -> 'rtk git status'"
  else
    echo "  FAIL  rtk-rewrite did not rewrite as expected (got: '$rewritten')"; fail=1
  fi
else
  if [ -z "$rw_out" ]; then
    echo "  ok  rtk-rewrite no-op'd cleanly (rtk not on PATH)"
    echo "  SKIP  positive rewrite assertion (rtk not on PATH in this image)"
  else
    echo "  FAIL  rtk-rewrite produced output without rtk on PATH: '$rw_out'"; fail=1
  fi
fi

echo "----"
[ "$fail" -eq 0 ] && echo "SMOKE: PASS" || echo "SMOKE: FAIL"
exit $fail
