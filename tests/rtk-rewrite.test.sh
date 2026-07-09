#!/bin/bash
# Drives rtk-rewrite.sh end-to-end: pipe a Bash PreToolUse JSON envelope, assert
# the rewritten .command (or a no-op = empty output / exit 0).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/rtk-rewrite.sh"

if ! command -v rtk >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: rtk or jq missing — rtk-rewrite.sh no-ops without them"
  exit 0
fi

pass=0; fail=0

# run <cmd>  ->  echoes rewritten command, or "" for no-op
run() {
  local out
  out=$(printf '%s' "{\"tool_input\":{\"command\":$(jq -Rn --arg c "$1" '$c')}}" | bash "$HOOK")
  [ -z "$out" ] && { echo ""; return; }
  echo "$out" | jq -r '.hookSpecificOutput.updatedInput.command // ""'
}

check() {  # desc  input  expected
  local got; got=$(run "$2")
  if [ "$got" = "$3" ]; then echo "PASS: $1"; pass=$((pass+1))
  else echo "FAIL: $1 — got [$got] want [$3]"; fail=$((fail+1)); fi
}

check "git status"        "git status"                 "rtk git status"
check "git commit -m x"   "git commit -m x"            "rtk git commit -m x"
check "gh pr list"        "gh pr list"                 "rtk gh pr list"
check "cargo test"        "cargo test"                 "rtk cargo test"
check "cat file"          "cat file.txt"               "rtk read file.txt"
check "grep pat f"        "grep pat file"              "rtk grep pat file"
check "head -20 file"     "head -20 app.log"           "rtk read app.log --max-lines 20"
check "env prefix kept"   "FOO=1 vitest run"           "FOO=1 rtk vitest run"
check "npm run build"     "npm run build"              "rtk npm build"
check "docker compose ps" "docker compose ps"          "rtk docker compose ps"
check "docker rm no-op"   "docker rm x"                ""
check "kubectl get pods"  "kubectl get pods"           "rtk kubectl get pods"
check "curl url"          "curl https://x"             "rtk curl https://x"
check "pnpm list"         "pnpm list"                  "rtk pnpm list"
check "pytest"            "pytest -q"                  "rtk pytest -q"
check "go test"           "go test ./..."              "rtk go test ./..."
check "aws s3 ls"         "aws s3 ls"                  "rtk aws s3 ls"
check "psql -l"           "psql -l"                    "rtk psql -l"
check "already rtk no-op" "rtk git status"             ""
check "unknown no-op"     "echo hi"                    ""

# RW-1: negatives (unmapped subcommands = no-op)
check "git reset --hard no-op"  "git reset --hard"           ""
check "gh alias list no-op"     "gh alias list"               ""
check "cargo run no-op"         "cargo run"                   ""
check "npm install no-op"       "npm install"                 ""
check "pnpm add x no-op"        "pnpm add x"                  ""
check "pip freeze no-op"        "pip freeze"                  ""
check "go run . no-op"          "go run ."                    ""
check "wget url"                "wget url"                    "rtk wget url"
check "ls -la"                  "ls -la"                      "rtk ls -la"

# RW-2: positives per files.sh / js-tooling.sh
check "head --lines=5 f"        "head --lines=5 f"            "rtk read f --max-lines 5"
check "find by name"            "find . -name foo.txt"        "rtk find . -name foo.txt"
check "diff two files"          "diff a.txt b.txt"            "rtk diff a.txt b.txt"
check "tree bare"               "tree"                        "rtk tree"
check "eslint ."                "eslint ."                    "rtk lint ."
check "prettier -w ."           "prettier -w ."               "rtk prettier -w ."
check "tsc -p ."                "tsc -p ."                    "rtk tsc -p ."
check "pnpm test"               "pnpm test"                   "rtk vitest run"
check "npx playwright test"     "npx playwright test"         "rtk playwright test"

# RW-3: containers.sh flag preservation
check "docker ps"                        "docker ps"                          "rtk docker ps"
check "kubectl --namespace foo get pods" "kubectl --namespace foo get pods"   "rtk kubectl --namespace foo get pods"

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
