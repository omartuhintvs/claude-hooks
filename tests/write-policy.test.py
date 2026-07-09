"""Drives guards/write-guard.py end-to-end against core/write-vectors.json.

Pipes each vector as a PreToolUse JSON envelope, asserts the emitted
permissionDecision matches the expected deny/ask/allow."""
import json
import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# TVS_WRITE_GUARD lets the docker smoke test drive the *installed* dispatcher
# (~/.claude/hooks/write-guard.py) with the exact same vectors.
GUARD = os.environ.get("TVS_WRITE_GUARD", os.path.join(REPO_ROOT, "guards", "write-guard.py"))

with open(os.path.join(REPO_ROOT, "core", "write-vectors.json")) as f:
    vectors = json.load(f)["vectors"]

pass_count = 0
fail_count = 0


def decision_for(cmd):
    payload = json.dumps({"tool_input": {"command": cmd}})
    out = subprocess.run(
        [sys.executable, GUARD], input=payload,
        capture_output=True, text=True,
    ).stdout
    return json.loads(out)["hookSpecificOutput"]["permissionDecision"]


for v in vectors:
    got = decision_for(v["cmd"])
    label = f'{v["expect"]}: {v["cmd"]}'
    if got == v["expect"]:
        print(f"PASS: {label}")
        pass_count += 1
    else:
        print(f"FAIL: {label} (got {got})")
        fail_count += 1

print("----")
print(f"pass={pass_count} fail={fail_count}")
sys.exit(0 if fail_count == 0 else 1)
