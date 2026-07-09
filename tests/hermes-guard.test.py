"""Drives the hermes adapter scan() against fake guard-all.sh scripts.

Focus: a real deny must NOT downgrade to allow when guard-all emits an exit-2 block
with malformed/empty stdout (the fail-closed contract)."""
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# hermes __init__ imports `.policy`; make core/policy.py importable as `policy`.
sys.path.insert(0, os.path.join(REPO, "core"))
sys.path.insert(0, os.path.join(REPO, "adapters", "hermes"))
import importlib.util

spec = importlib.util.spec_from_file_location(
    "hermes_guard", os.path.join(REPO, "adapters", "hermes", "__init__.py")
)
hermes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hermes)

passed = failed = 0


def fake_guard(body):
    fd, path = tempfile.mkstemp(suffix=".sh")
    os.write(fd, ("#!/bin/bash\n" + body).encode())
    os.close(fd)
    os.chmod(path, 0o755)
    return path


def check(desc, guard_body, command, want_action):
    global passed, failed
    os.environ["TVS_GUARD_ALL"] = fake_guard(guard_body)
    got = hermes.scan("bash", {"command": command}).get("action")
    if got == want_action:
        print(f"PASS: {desc}"); passed += 1
    else:
        print(f"FAIL: {desc} — got {got} want {want_action}"); failed += 1


# Real deny, valid JSON -> block.
check("deny JSON -> block",
      'echo \'{"hookSpecificOutput":{"permissionDecision":"deny"}}\'; exit 2',
      "git push", "block")
# THE BUG: exit-2 block but empty/malformed stdout must still block, not allow.
check("exit2 + empty stdout -> block (fail-closed)",
      'exit 2', "git push", "block")
check("exit2 + garbage stdout -> block",
      'echo not-json; exit 2', "git commit -m x", "block")
# Genuine allow -> allow.
check("allow JSON exit0 -> allow",
      'echo \'{"hookSpecificOutput":{"permissionDecision":"allow"}}\'; exit 0',
      "git status", "allow")
# Spawn failure on a non-dangerous command -> allow (fail-open, unrelated work).
check("unspawnable + echo -> allow",
      'exit 0', "echo hi", "allow")  # guard runs, allows

os.environ["TVS_GUARD_ALL"] = "/nonexistent/guard-all.sh"
r = hermes.scan("bash", {"command": "git push"}).get("action")
if r == "block":
    print("PASS: unspawnable + push -> block (fail-closed)"); passed += 1
else:
    print(f"FAIL: unspawnable + push — got {r} want block"); failed += 1

print("----")
print(f"pass={passed} fail={failed}")
sys.exit(0 if failed == 0 else 1)
