#!/bin/bash
# Integration tests for generic TVS identity hooks (domain model, committer-required,
# strict-author opt-in) — the guards/git-hooks/_dispatch and guards/identity-guard.sh
# end-to-end, wired to the repo's own core/policy.sh via TVS_SHIELD_HOME.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$DIR/.." && pwd)"
export TVS_SHIELD_HOME="$SRC"
TVS1=alice@technovativesolutions.co.uk
TVS2=bob@digiprodpass.com
GMAIL=someone@gmail.com
FOREIGN=ext@contractor.io
TMP=$(mktemp -d)
pass=0; fail=0
ok(){ if [ "$1" = "$2" ]; then echo "PASS: $3"; pass=$((pass+1)); else echo "FAIL: $3 (got=$1 want=$2)"; fail=$((fail+1)); fi; }

# global git-hook dir with _dispatch symlinked
HK="$TMP/git-hooks"; mkdir -p "$HK"; cp "$SRC/guards/git-hooks/_dispatch" "$HK/_dispatch"; chmod +x "$HK/_dispatch"
for h in pre-commit pre-push; do ln -sf _dispatch "$HK/$h"; done
PC="$HK/pre-commit"; PP="$HK/pre-push"; IG="$SRC/guards/identity-guard.sh"
Z=0000000000000000000000000000000000000000

mkrepo(){ local d="$TMP/$1"; mkdir -p "$d"; git -C "$d" init -q; git -C "$d" remote add origin "$2"; echo "$d"; }
# a commit authored/committed by given emails, hooks bypassed at creation
mkcommit(){ git -C "$1" -c user.name=x -c user.email="$3" \
  -c author.name=x commit -q --no-verify --allow-empty --author="x <$2>" -m c; git -C "$1" rev-parse HEAD; }

# ---- pre-commit (committer-required) ----
r=$(mkrepo c1 git@github.com:digiprodpass/x.git)
pc(){ ( cd "$1" && GIT_AUTHOR_NAME=x GIT_COMMITTER_NAME=x GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_EMAIL="$3" "$PC" ); echo $?; }
ok $(pc "$r" $TVS1 $TVS1) 0 "pc: tvs committer (.co.uk) -> allow"
ok $(pc "$r" $TVS2 $TVS2) 0 "pc: tvs committer (digiprodpass.com) -> allow"
ok $(pc "$r" $GMAIL $GMAIL) 1 "pc: gmail committer in tvs repo -> block"
ok $(pc "$r" $FOREIGN $TVS1) 0 "pc: foreign author + tvs committer -> allow"
ok $(pc "$r" $TVS1 $GMAIL) 1 "pc: gmail committer, tvs author -> block"
# strict author mode
git -C "$r" config hooks.requireWorkAuthor true
ok $(pc "$r" $FOREIGN $TVS1) 1 "pc: strict-author, foreign author -> block"
ok $(pc "$r" $TVS2 $TVS1) 0 "pc: strict-author, tvs author+committer -> allow"
git -C "$r" config --unset hooks.requireWorkAuthor
# non-tvs repo untouched
r2=$(mkrepo c2 git@github.com:someorg/y.git)
ok $(pc "$r2" $GMAIL $GMAIL) 0 "pc: non-tvs repo + gmail -> allow (untouched)"

# ---- pre-push (committer scan, fail-closed) ----
pp(){ ( cd "$1" && echo "refs/heads/main $2 refs/heads/main $Z" | "$PP" "$3" "$4" ); echo $?; }
r=$(mkrepo p1 git@github.com:digiprodpass/x.git); sha=$(mkcommit "$r" $GMAIL $GMAIL)
ok $(pp "$r" $sha origin git@github.com:digiprodpass/x.git) 1 "pp: gmail committer new branch -> block"
r=$(mkrepo p2 git@github.com:digiprodpass/x.git); sha=$(mkcommit "$r" $TVS1 $TVS1)
ok $(pp "$r" $sha origin git@github.com:digiprodpass/x.git) 0 "pp: tvs committer -> allow"
r=$(mkrepo p3 git@github.com:digiprodpass/x.git); sha=$(mkcommit "$r" $FOREIGN $TVS1)
ok $(pp "$r" $sha origin git@github.com:digiprodpass/x.git) 0 "pp: foreign author + tvs committer -> allow"
# explicit-URL push (dest not a configured remote): whole-history scan
r=$(mkrepo p4 git@github.com:digiprodpass/x.git); sha=$(mkcommit "$r" $GMAIL $GMAIL)
ok $(pp "$r" $sha git@github.com:digiprodpass/x.git git@github.com:digiprodpass/x.git) 1 "pp: url-push gmail committer -> block"
r=$(mkrepo p5 git@github.com:someorg/y.git); sha=$(mkcommit "$r" $GMAIL $GMAIL)
ok $(pp "$r" $sha origin git@github.com:someorg/y.git) 0 "pp: non-tvs repo -> allow"

# ---- identity-guard.sh (Claude PreToolUse) ----
ig(){ printf '{"tool_input":{"command":%s},"cwd":%s}' "$(printf '%s' "$2" | jq -R .)" "$(printf '%s' "$1" | jq -R .)" | "$IG"; echo $?; }
r=$(mkrepo g1 git@github.com:digiprodpass/x.git); git -C "$r" config user.email $TVS1
ok $(ig "$r" "git -c user.email=$GMAIL commit -m x") 2 "ig: inline gmail in tvs repo -> block"
ok $(ig "$r" "git commit -m x") 0 "ig: tvs config email -> allow"
ok $(ig "$r" "git -c user.email=$TVS2 commit -m x") 0 "ig: inline company email -> allow"
git -C "$r" config user.email $GMAIL
ok $(ig "$r" "git commit -m x") 2 "ig: gmail config email in tvs repo -> block"
r2=$(mkrepo g2 git@github.com:someorg/y.git); git -C "$r2" config user.email $GMAIL
ok $(ig "$r2" "git commit -m x") 0 "ig: non-tvs repo + gmail -> allow"
ok $(ig "$r" "git commit --author=\"Ext <$FOREIGN>\" -m x") 2 "ig: inline foreign author in tvs repo -> block"
# reset r's config back to company for the false-block tests
git -C "$r" config user.email $TVS1
# Major#4: email only in commit MESSAGE, config is company -> allow (no false block)
ok $(ig "$r" "git commit -m \"docs: set user.email e.g. dev@gmail.com\"") 0 "ig: email in message only -> allow"
# Major#2: gmail injected inline while a company email sits in the message -> block
ok $(ig "$r" "git -c user.email=$GMAIL commit -m \"cc support@digiprodpass.com\"") 2 "ig: inline gmail + company email in msg -> block"
# Major#2 anchor: suffix trick inline -> block
ok $(ig "$r" "git -c user.email=evil@technovativesolutions.co.uk.attacker.com commit -m x") 2 "ig: suffix-trick inline email -> block"
# Critical#1: eval RCE — proposing this must NOT execute the substitution
rm -f "$TMP/PWNED"
ig "$r" "cd \"\$(touch $TMP/PWNED)\" && git commit -m x" >/dev/null 2>&1
if [ -e "$TMP/PWNED" ]; then echo "FAIL: ig: eval RCE — command substitution executed!"; fail=$((fail+1)); else echo "PASS: ig: no eval RCE"; pass=$((pass+1)); fi

# ---- missing core (fail-closed) ----
# TVS_SHIELD_HOME points at a dir with no core/policy.sh -> both guards must refuse,
# not fail-open. Only these two invocations get the nonexistent home; everything else
# above/below keeps using the repo's own TVS_SHIELD_HOME ($SRC).
missing_code=$(TVS_SHIELD_HOME=/nonexistent-tvs-dir bash -c '
  printf "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"'"$r"'\"}" | "'"$IG"'"
  echo $?
' | tail -1)
ok "$missing_code" 2 "ig: missing core/policy.sh -> fail closed (exit 2)"

missing_pc_code=$(cd "$r" && TVS_SHIELD_HOME=/nonexistent-tvs-dir GIT_AUTHOR_NAME=x GIT_COMMITTER_NAME=x GIT_AUTHOR_EMAIL="$TVS1" GIT_COMMITTER_EMAIL="$TVS1" "$PC"; echo $?)
ok "$missing_pc_code" 1 "pre-commit dispatch: missing core/policy.sh -> fail closed (exit 1)"

echo "----"; echo "pass=$pass fail=$fail"; rm -rf "$TMP"; [ "$fail" = 0 ]
