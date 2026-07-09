#!/bin/bash
# Unified guard chain. One PreToolUse entry point that runs every block-guard and
# resolves a single decision, so every hook-capable agent gets the full stack.
#
# Chain (all fed the SAME stdin JSON envelope, buffered once and replayed):
#   1. write-guard.py  — python driver over core/write-policy/*.py (docker, psql,
#      doctl, kubectl, commit-attribution, ...). Signals via stdout JSON
#      permissionDecision and ALWAYS exits 0. Convenience guard: fail-OPEN.
#   2. identity-guard.sh — company-email guard. Signals via exit code (2 = deny).
#      Core mission: fail-CLOSED for commit-ish commands.
#   3. block-git-push.sh — push accident guard. Exit 2 = deny. Fail-CLOSED for
#      push commands.
#
# Precedence across the chain: deny > ask > allow (a later hard deny is never
# masked by an earlier ask).
#
# Dual-signal output so both consumer styles are served:
#   - stdout: Claude-style JSON { hookSpecificOutput: { permissionDecision, ... } }
#   - stderr: the reason (on deny/ask)
#   - exit code: deny -> 2, allow -> 0, ask -> 0 (default) or 2 (--ask-block).
# Claude reads the JSON and wants ask=exit0; exit-code-only consumers (CommandCode)
# can't express "ask", so they pass --ask-block to collapse ask -> deny/exit2.
set -uo pipefail

# ask exit policy: 0 (Claude/JSON consumers) unless --ask-block / TVS_GUARD_ASK_BLOCK=1.
ASK_BLOCK=0
[ "${TVS_GUARD_ASK_BLOCK:-0}" = 1 ] && ASK_BLOCK=1
[ "${1:-}" = "--ask-block" ] && ASK_BLOCK=1

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITE_GUARD="${TVS_WRITE_GUARD:-$_here/write-guard.py}"
IDENTITY_GUARD="${TVS_IDENTITY_GUARD:-$_here/identity-guard.sh}"
PUSH_GUARD="${TVS_GIT_PUSH_HOOK:-$_here/block-git-push.sh}"

# Buffer stdin once — every child needs the same envelope; a bare pipe feeds only one.
input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"

# Fail-scoping regexes (mirror core/policy.{sh,mjs}). Used ONLY to decide whether a
# CRASHED shell guard should fail closed — never to make an allow decision.
is_commit_cmd() { printf '%s' "$1" | grep -qE '\bgit\b[^|&;]*\b(commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am)\b'; }
is_push_cmd()   { printf '%s' "$1" | grep -qE '\bgit\b[^|&;]*\bpush([[:space:]]|$)'; }

# Accumulated decision + reason. deny > ask > allow.
decision="allow"; reason=""
raise() {  # raise <deny|ask> <reason>
  case "$1" in
    deny) decision="deny"; reason="$2" ;;
    ask)  [ "$decision" = deny ] || { decision="ask"; reason="$2"; } ;;
  esac
}

# --- guard 1: python write-policy driver (fail-open) -------------------------
if command -v python3 >/dev/null 2>&1 && [ -f "$WRITE_GUARD" ]; then
  wg_out="$(printf '%s' "$input" | python3 "$WRITE_GUARD" 2>/dev/null)"
  wg_dec="$(printf '%s' "$wg_out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  wg_reason="$(printf '%s' "$wg_out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)"
  case "$wg_dec" in
    deny) raise deny "[write-guard] ${wg_reason:-write policy blocked}" ;;
    ask)  raise ask  "[write-guard] ${wg_reason:-needs confirmation}" ;;
    allow|"") : ;;  # empty/malformed => fail-open (convenience guard)
  esac
elif ! command -v python3 >/dev/null 2>&1; then
  echo "TVS guard-all: python3 absent — write-policy driver skipped (fail-open)." >&2
fi

# --- guard 2: identity-guard.sh (fail-closed for commit-ish) -----------------
if [ -x "$IDENTITY_GUARD" ] || [ -f "$IDENTITY_GUARD" ]; then
  id_err="$(printf '%s' "$input" | bash "$IDENTITY_GUARD" 2>&1 >/dev/null)"; id_code=$?
  if [ "$id_code" = 2 ]; then
    raise deny "[identity-guard] ${id_err:-commit blocked by identity policy}"
  elif [ "$id_code" != 0 ] && is_commit_cmd "$command"; then
    raise deny "[identity-guard] guard crashed on a commit command — refusing (fail-closed)."
  fi
elif is_commit_cmd "$command"; then
  raise deny "[identity-guard] guard missing — refusing commit (fail-closed)."
fi

# --- guard 3: block-git-push.sh (fail-closed for push) -----------------------
if [ -x "$PUSH_GUARD" ] || [ -f "$PUSH_GUARD" ]; then
  pu_err="$(printf '%s' "$input" | bash "$PUSH_GUARD" 2>&1 >/dev/null)"; pu_code=$?
  if [ "$pu_code" = 2 ]; then
    raise deny "[block-git-push] ${pu_err:-git push blocked}"
  elif [ "$pu_code" != 0 ] && is_push_cmd "$command"; then
    raise deny "[block-git-push] guard crashed on a push command — refusing (fail-closed)."
  fi
elif is_push_cmd "$command"; then
  raise deny "[block-git-push] guard missing — refusing push (fail-closed)."
fi

# --- emit dual-signal --------------------------------------------------------
emit_json() {  # emit_json <decision> <reason>
  if [ "$1" = allow ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
  else
    jq -cn --arg d "$1" --arg r "$2" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  fi
}

emit_json "$decision" "$reason"
case "$decision" in
  deny) echo "$reason" >&2; exit 2 ;;
  ask)  echo "$reason" >&2; [ "$ASK_BLOCK" = 1 ] && exit 2 || exit 0 ;;
  allow) exit 0 ;;
esac
