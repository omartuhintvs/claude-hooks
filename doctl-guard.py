#!/usr/bin/env python3
"""Block any Bash command that invokes `doctl`.

Guardrail: Claude must never run DigitalOcean CLI (doctl) commands.
Instead it must print/hand the command to the user to run manually.
Catches direct calls and chained/piped invocations (;, &&, |, $(...)).
Exit 2 = block (stderr shown to Claude). Exit 0 = allow.
"""
import json
import re
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # fail open on unparseable input; other guards still apply

cmd = (data.get("tool_input", {}) or {}).get("command", "") or ""

# Word-boundary match so paths like "/x/mydoctly" don't trip it,
# but "doctl ...", "; doctl", "$(doctl ...)", "|doctl" all do.
if re.search(r"(?:^|[\s;&|()`$])doctl\b", cmd):
    sys.stderr.write(
        "Blocked: `doctl` (DigitalOcean CLI) is disallowed for Claude by guardrail.\n"
        "Do NOT run it. Print the exact doctl command and ask the user to run it manually.\n"
    )
    sys.exit(2)

sys.exit(0)
