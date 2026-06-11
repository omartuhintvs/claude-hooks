#!/usr/bin/env python3
"""Block destructive/mutating kubectl (or `kc`) commands.

Guardrail: Claude must never run destructive kubectl commands. It must
print the exact command and ask the user to run it / confirm.
Read-only verbs (get, describe, logs, top, rollout status, ...) are allowed.
Exit 2 = block (stderr shown to Claude). Exit 0 = allow.
"""
import json
import re
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # fail open; other guards still apply

cmd = (data.get("tool_input", {}) or {}).get("command", "") or ""

# Only consider commands that invoke kubectl or the `kc` alias.
if not re.search(r"(?:^|[\s;&|()`$])(?:kubectl|kc)\b", cmd):
    sys.exit(0)

# Destructive / mutating verbs. `rollout restart|undo` are destructive;
# `rollout status|history` are read-only and must stay allowed.
DESTRUCTIVE = (
    r"delete|drain|cordon|uncordon|taint|replace|patch|scale|edit|apply|"
    r"create|set|annotate|label|expose|autoscale|"
    r"rollout\s+(?:restart|undo)"
)

# Match a kubectl/kc invocation followed (allowing flags) by a destructive
# verb, within the same command segment (not across ; && | redirects).
pattern = re.compile(
    r"(?:^|[\s;&|()`$])(?:kubectl|kc)\b[^;&|<>]*?\b(?:" + DESTRUCTIVE + r")\b"
)

if pattern.search(cmd):
    sys.stderr.write(
        "Blocked: destructive kubectl command is disallowed for Claude by guardrail.\n"
        "Do NOT run it. Print the exact command in a code block and ask the user "
        "to confirm and run it manually.\n"
    )
    sys.exit(2)

sys.exit(0)
