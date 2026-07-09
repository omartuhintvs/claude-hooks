#!/bin/bash
# Block Claude Code from committing to a TVS org repo under a non-company email.
# PreToolUse Bash hook: runs BEFORE the command, so it cannot trust the repo's
# CURRENT config alone (a `git config user.email personal && git commit` chain would
# read the pre-chain value). Model: in a TVS repo, block if a non-company email is
# injected in an identity-assignment position, or if the stored config email is not a
# company address and no company identity is injected inline.
#
# TVS repo = a remote URL in github.com/technovativesolutions/* or github.com/digiprodpass/*.
# Company email = @technovativesolutions.co.uk or @digiprodpass.com.
# This is the Claude-layer twin of git-hooks/_dispatch; the git hook is the real
# backstop (it reads the actual commit identity), so this stays deliberately simple.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Any commit-creating git verb, incl. common aliases and verbs that write commits.
verbs='commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am'
if ! echo "$command" | grep -qE "\bgit\b[^|&;]*\b($verbs)\b"; then
  exit 0
fi

# A single extracted email token is matched whole, so the $ anchor is safe against
# suffix tricks (evil@technovativesolutions.co.uk.attacker.com won't match).
WORK_RE='@(technovativesolutions\.co\.uk|digiprodpass\.com)$'
EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# Resolve the repo the commit targets: honor `git -C <path>`, `--git-dir=`, `GIT_DIR=`,
# a leading `cd`/`pushd <path>`, else the session cwd. NO eval — quote-strip + tilde only.
target="$cwd"
cflag=$(echo "$command" | grep -oE 'git +-C +[^ ]+' | head -1 | awk '{print $3}')
[ -n "$cflag" ] && target="$cflag"
gd=$(echo "$command" | grep -oiE '(--git-dir=|GIT_DIR=)[^ ]+' | head -1 | sed -E 's/.*=//')
[ -n "$gd" ] && target="${gd%/.git}"
cdpath=$(echo "$command" | grep -oiE '(^|[;&|] *)(cd|pushd) +[^&|;)]+' | head -1 | sed -E 's/.*(cd|pushd) +//' | sed 's/[[:space:]]*$//')
if [ -n "$cdpath" ]; then
  cdpath="${cdpath%\"}"; cdpath="${cdpath#\"}"; cdpath="${cdpath%\'}"; cdpath="${cdpath#\'}"
  case "$cdpath" in
    "~")    cdpath="$HOME" ;;
    "~/"*)  cdpath="$HOME/${cdpath#\~/}" ;;
  esac
  target="$cdpath"
fi

email=""; remote=""
if [ -n "$target" ] && [ -d "$target" ]; then
  toplevel=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)
  [ -n "$toplevel" ] && target="$toplevel"
  email=$(git -C "$target" config user.email 2>/dev/null)
  # URLs only (2nd column) — a remote NAME containing a decoy org must not classify.
  remote=$(git -C "$target" remote -v 2>/dev/null | awk '{print $2}')
fi

# TVS repo? By remote org, or by a TVS org marker in the command itself.
is_work=0
echo "$remote"  | grep -qiE '[:/](technovativesolutions|digiprodpass)/' && is_work=1
echo "$command" | grep -qiE '[:/](technovativesolutions|digiprodpass)/' && is_work=1
[ "$is_work" = 1 ] || exit 0

# Emails in an IDENTITY-ASSIGNMENT position only (never the commit message). Covers
# -c user.email=X, GIT_AUTHOR_EMAIL=X, GIT_COMMITTER_EMAIL=X, and --author="N <X>".
assigned=$(
  echo "$command" | grep -oiE "(user\.email=|GIT_AUTHOR_EMAIL=|GIT_COMMITTER_EMAIL=)$EMAIL" | grep -oiE "$EMAIL"
  echo "$command" | grep -oiE -- "--author[= ]+\"?[^\"]*\"?" | grep -oiE "$EMAIL"
)

# Any injected identity email that is NOT a company address -> block.
injected_any=0
while IFS= read -r e; do
  [ -z "$e" ] && continue
  injected_any=1
  if ! echo "$e" | grep -qiE "$WORK_RE"; then
    echo "ERROR: TVS repo but the commit injects a non-company email ($e). Use a company identity: git config user.email you@technovativesolutions.co.uk" >&2
    exit 2
  fi
done <<EOF
$assigned
EOF

# No inline identity override: fall back to the stored config email.
if [ "$injected_any" = 0 ] && [ -n "$email" ] && ! echo "$email" | grep -qiE "$WORK_RE"; then
  echo "ERROR: TVS repo but user.email is ($email), not a company address. Set it: git config user.email you@technovativesolutions.co.uk" >&2
  exit 2
fi

exit 0
