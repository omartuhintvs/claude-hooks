#!/bin/bash
# Regression gate. Every suite must be green before any "done" claim.
set -uo pipefail
cd "$(dirname "$0")/.."
export TVS_SHIELD_HOME="$PWD"
fail=0
run() {  # run <label> <cmd...>
  local label="$1"; shift
  local out; out="$("$@" 2>&1 | tail -1)"
  if printf '%s' "$out" | grep -qE 'fail=0|SMOKE: PASS'; then printf '  ok   %-20s %s\n' "$label" "$out"
  else printf '  FAIL %-20s %s\n' "$label" "$out"; fail=1; fi
}
run write-policy python3 tests/write-policy.test.py
run git-push     bash   tests/git-push.test.sh
run policy-sh    bash   tests/policy.test.sh
run policy-mjs   node   tests/policy.test.mjs
run policy-py    python3 tests/policy.test.py
run integration  bash   tests/integration.test.sh
run guard-all    bash   tests/guard-all.test.sh
run guard-plugin node   tests/guard-plugin.test.mjs
run rtk-rewrite  bash   tests/rtk-rewrite.test.sh
run hermes-guard python3 tests/hermes-guard.test.py
echo "----"
[ "$fail" -eq 0 ] && echo "CHECKS: PASS" || echo "CHECKS: FAIL"
exit $fail
