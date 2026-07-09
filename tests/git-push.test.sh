#!/bin/bash
# Drives block-git-push.sh end-to-end: pipe a Bash PreToolUse JSON envelope,
# assert exit 2 (blocked) or exit 0 (allowed).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# TVS_GIT_PUSH_HOOK lets the docker smoke test drive the installed copy.
HOOK="${TVS_GIT_PUSH_HOOK:-$REPO_ROOT/block-git-push.sh}"

pass=0; fail=0

# check <desc> <cmd> <block|allow>
check() {
  local want_code got
  [ "$3" = block ] && want_code=2 || want_code=0
  printf '%s' "{\"tool_input\":{\"command\":$(jq -Rn --arg c "$2" '$c')}}" | bash "$HOOK" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want_code" ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1 — got exit $got want $want_code"; fail=$((fail+1)); fi
}

# Blocked: real pushes, including the -C / --git-dir accident paths.
check "plain push"          "git push"                        block
check "push with remote"    "git push origin main"            block
check "git -C bypass"       "git -C /repo push origin main"   block
check "git --git-dir"       "git --git-dir=/r/.git push"      block
check "env prefix push"     "FOO=1 git push"                  block
check "force push"          "git push --force origin main"    block

# Allowed: non-push git, and push appearing only as a word fragment.
check "status"              "git status"                      allow
check "commit"              "git commit -m x"                 allow
check "config push.default" "git config push.default current" allow
check "log grep pushups"    "git log --grep pushups"          allow
check "plain echo"          "echo hello"                      allow

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
