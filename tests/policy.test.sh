#!/bin/bash
# Unit tests for core/policy.sh against the shared parity vectors in core/vectors.json.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../core/policy.sh"
VECTORS="$DIR/../core/vectors.json"

pass=0; fail=0
ok() { if [ "$1" = 0 ]; then echo "PASS: $2"; pass=$((pass+1)); else echo "FAIL: $2"; fail=$((fail+1)); fi; }

while IFS= read -r v; do
  tvs_is_work_email "$v"; ok $? "workEmail: $v"
done < <(jq -r '.workEmails[]' "$VECTORS")

while IFS= read -r v; do
  tvs_is_work_email "$v"; [ $? -ne 0 ]; ok $? "nonWorkEmail: $v"
done < <(jq -r '.nonWorkEmails[]' "$VECTORS")

while IFS= read -r v; do
  tvs_url_is_work "$v"; ok $? "workUrl: $v"
done < <(jq -r '.workUrls[]' "$VECTORS")

while IFS= read -r v; do
  tvs_url_is_work "$v"; [ $? -ne 0 ]; ok $? "nonWorkUrl: $v"
done < <(jq -r '.nonWorkUrls[]' "$VECTORS")

while IFS= read -r v; do
  tvs_is_commit_cmd "$v"; ok $? "commitCommand: $v"
done < <(jq -r '.commitCommands[]' "$VECTORS")

while IFS= read -r v; do
  tvs_is_commit_cmd "$v"; [ $? -ne 0 ]; ok $? "nonCommitCommand: $v"
done < <(jq -r '.nonCommitCommands[]' "$VECTORS")

echo "----"
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
