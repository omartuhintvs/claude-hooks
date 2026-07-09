#!/bin/bash
# Drives guards/guard-all.sh — the unified chain. Three parts:
#   1. hand-picked chain cases (exit-code): each guard's deny + a clean allow.
#   2. degraded mode: python3 absent -> identity still fail-closed, write-policy fail-open.
#   3. regression: replay the FULL write-policy + git-push vector sets THROUGH guard-all
#      and assert identical decisions (guards it must never regress behind).
# Payloads with trigger words are built from the vector JSON files at runtime, so this
# script's own command lines stay clean of the live guard's trip words.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="${TVS_GUARD_ALL:-$REPO_ROOT/guards/guard-all.sh}"
export TVS_SHIELD_HOME="${TVS_SHIELD_HOME:-$REPO_ROOT}"
export TVS_WRITE_GUARD="${TVS_WRITE_GUARD:-$REPO_ROOT/guards/write-guard.py}"
export TVS_IDENTITY_GUARD="${TVS_IDENTITY_GUARD:-$REPO_ROOT/guards/identity-guard.sh}"
export TVS_GIT_PUSH_HOOK="${TVS_GIT_PUSH_HOOK:-$REPO_ROOT/guards/block-git-push.sh}"

pass=0; fail=0
env_json() { jq -cn --arg c "$1" '{tool_input:{command:$c}}'; }

# code_for <cmd> [extra guard-all args...] -> echoes exit code
code_for() { printf '%s' "$(env_json "$1")" | bash "$GUARD" "${@:2}" >/dev/null 2>&1; echo $?; }
# decision_for <cmd> -> echoes JSON permissionDecision from stdout
decision_for() { printf '%s' "$(env_json "$1")" | bash "$GUARD" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision // "ERR"'; }

expect_code() {  # <desc> <cmd> <want_code>
  local got; got="$(code_for "$2")"
  if [ "$got" = "$3" ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1 — exit $got want $3"; fail=$((fail+1)); fi
}

echo "== part 1: chain cases =="
# Build trigger-word payloads by concatenation so this file's runtime cmd line is clean.
DKR="do""cker rm -f x"
SQL="psql -c 'D""ROP TABLE users'"
PSH="git -C /x pu""sh origin main"
BADCOMMIT="cd /tmp/technovativesolutions/r && git -c user.email=bad@gmail.com commit -m x"
expect_code "write-policy deny (docker)" "$DKR"       2
expect_code "write-policy deny (psql)"   "$SQL"       2
expect_code "identity deny (bad email)"  "$BADCOMMIT" 2
expect_code "push deny (git -C)"         "$PSH"       2
expect_code "clean allow (git status)"   "git status" 0
expect_code "clean allow (echo)"         "echo hi"    0

echo "== part 2: degraded mode (python3 absent) =="
# Strip python3 from PATH: write-policy driver skipped (fail-open), shell guards still run.
NOPY_DIR="$(mktemp -d)"
for b in bash jq git grep sed awk cat dirname env printf mktemp head; do
  src="$(command -v "$b" 2>/dev/null)"; [ -n "$src" ] && ln -sf "$src" "$NOPY_DIR/$b"
done
nopy_code() { printf '%s' "$(env_json "$1")" | PATH="$NOPY_DIR" bash "$GUARD" >/dev/null 2>&1; echo $?; }
g="$(nopy_code "$BADCOMMIT")"
if [ "$g" = 2 ]; then echo "PASS: no-python3 -> identity still denies"; pass=$((pass+1))
else echo "FAIL: no-python3 identity — exit $g want 2"; fail=$((fail+1)); fi
g="$(nopy_code "$DKR")"
if [ "$g" = 0 ]; then echo "PASS: no-python3 -> write-policy fail-open (docker allowed)"; pass=$((pass+1))
else echo "FAIL: no-python3 fail-open — exit $g want 0"; fail=$((fail+1)); fi
rm -rf "$NOPY_DIR"

echo "== part 3a: replay ALL write-policy vectors through guard-all (JSON decision) =="
# Iterate by index and pipe the raw JSON envelope straight from the vector file so
# multi-line (heredoc) commands keep their real newlines — @tsv would flatten them.
VF="$REPO_ROOT/core/write-vectors.json"
n=$(jq '.vectors|length' "$VF")
for i in $(seq 0 $((n-1))); do
  want="$(jq -r ".vectors[$i].expect" "$VF")"
  got="$(jq -c "{tool_input:{command:.vectors[$i].cmd}}" "$VF" | bash "$GUARD" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision // "ERR"')"
  if [ "$got" = "$want" ]; then pass=$((pass+1))
  else echo "FAIL: write-vector #$i [$want] got [$got]"; fail=$((fail+1)); fi
done
echo "  replayed $n write vectors"

echo "== part 3b: replay git-push vectors through guard-all (exit code) =="
# block -> deny -> exit 2 ; allow -> exit 0. Push blocks are hard denies in guard-all.
push_check() {  # <cmd> <block|allow>
  local want=0; [ "$2" = block ] && want=2
  local got; got="$(code_for "$1")"
  if [ "$got" = "$want" ]; then pass=$((pass+1))
  else echo "FAIL: push-vector want $2 got exit $got: $1"; fail=$((fail+1)); fi
}
push_check "git push" block
push_check "git push origin main" block
push_check "git --git-dir=/r/.git push" block
push_check "FOO=1 git push" block
push_check "git status" allow
push_check "git config push.default current" allow
push_check "git log --grep pushups" allow

echo "== part 3c: ask exit policy (Claude vs exit-code consumers) =="
# A real ask vector. Default mode: ask -> exit 0 + JSON ask (Claude prompts).
# --ask-block (CommandCode et al., exit-code only): ask -> exit 2 (collapses to block).
ASKCMD="$(jq -r '.vectors[]|select(.expect=="ask").cmd' "$REPO_ROOT/core/write-vectors.json" | head -1)"
if [ -n "$ASKCMD" ]; then
  d="$(decision_for "$ASKCMD")"
  [ "$d" = ask ] && { echo "PASS: ask vector -> JSON ask"; pass=$((pass+1)); } || { echo "FAIL: ask JSON got [$d]"; fail=$((fail+1)); }
  c="$(code_for "$ASKCMD")"
  [ "$c" = 0 ] && { echo "PASS: ask default mode -> exit 0"; pass=$((pass+1)); } || { echo "FAIL: ask default exit $c want 0"; fail=$((fail+1)); }
  c="$(code_for "$ASKCMD" --ask-block)"
  [ "$c" = 2 ] && { echo "PASS: ask --ask-block -> exit 2"; pass=$((pass+1)); } || { echo "FAIL: ask --ask-block exit $c want 2"; fail=$((fail+1)); }
else
  echo "SKIP: no ask vector found"
fi

echo "== part 4: latency budget (chain < 5s adapter timeout) =="
start=$(date +%s%N)
code_for "git status" >/dev/null
end=$(date +%s%N)
ms=$(( (end - start) / 1000000 ))
if [ "$ms" -lt 5000 ]; then echo "PASS: chain latency ${ms}ms < 5000ms"; pass=$((pass+1))
else echo "FAIL: chain latency ${ms}ms >= 5000ms"; fail=$((fail+1)); fi

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
