"""Unit tests for core/policy.py against the shared parity vectors in core/vectors.json."""
import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "core"))

from policy import is_work_email, url_is_work, is_commit_command  # noqa: E402

with open(os.path.join(REPO_ROOT, "core", "vectors.json")) as f:
    vectors = json.load(f)

pass_count = 0
fail_count = 0


def ok(cond, label):
    global pass_count, fail_count
    if cond:
        print(f"PASS: {label}")
        pass_count += 1
    else:
        print(f"FAIL: {label}")
        fail_count += 1


for v in vectors["workEmails"]:
    ok(is_work_email(v), f"workEmail: {v}")
for v in vectors["nonWorkEmails"]:
    ok(not is_work_email(v), f"nonWorkEmail: {v}")
for v in vectors["workUrls"]:
    ok(url_is_work(v), f"workUrl: {v}")
for v in vectors["nonWorkUrls"]:
    ok(not url_is_work(v), f"nonWorkUrl: {v}")
for v in vectors["commitCommands"]:
    ok(is_commit_command(v), f"commitCommand: {v}")
for v in vectors["nonCommitCommands"]:
    ok(not is_commit_command(v), f"nonCommitCommand: {v}")

print("----")
print(f"pass={pass_count} fail={fail_count}")
sys.exit(0 if fail_count == 0 else 1)
