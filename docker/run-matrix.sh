#!/bin/bash
# Builds & runs every Dockerfile.{smoke,opencode,codex} leg and prints a per-agent
# PASS/FAIL table. Run from the repo root: bash docker/run-matrix.sh
set -uo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found on PATH — cannot run the container matrix." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

declare -a NAMES=(claude opencode codex)
declare -a FILES=(docker/Dockerfile.smoke docker/Dockerfile.opencode docker/Dockerfile.codex)
declare -a RESULTS=()

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; file="${FILES[$i]}"; tag="tvs-shield-matrix-$name"
  echo "== building $name ($file) =="
  if docker build -q -f "$file" -t "$tag" . >/tmp/matrix-build-$name.log 2>&1; then
    echo "== running $name =="
    if docker run --rm "$tag" >/tmp/matrix-run-$name.log 2>&1; then
      RESULTS+=("PASS")
    else
      RESULTS+=("FAIL")
    fi
    tail -5 "/tmp/matrix-run-$name.log"
  else
    echo "  build failed — see /tmp/matrix-build-$name.log"
    RESULTS+=("FAIL")
  fi
  echo ""
done

echo "== matrix =="
line=""
overall=0
for i in "${!NAMES[@]}"; do
  r="${RESULTS[$i]}"
  [ "$r" = "FAIL" ] && overall=1
  line="$line${NAMES[$i]} $r  "
done
echo "$line"
exit $overall
