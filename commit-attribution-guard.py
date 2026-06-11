#!/usr/bin/env python3
"""Block any `git commit` that embeds Claude/AI attribution.

Guardrail: commit messages must never contain `Co-Authored-By: Claude`
(or any Claude/AI co-author) nor the "Generated with Claude Code" footer.
The Claude Code harness default tells the model to add these; the user's
CLAUDE.md forbids them. This hook enforces the user's rule.

Catches the common inline forms (`-m "..."`, heredocs). File-based messages
(`-F file`, `--file`) can't be inspected and pass through.

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

# Only inspect git commit invocations (incl. `git -C path commit`, `git commit --amend`).
if not re.search(r"\bgit\b[^\n]*\bcommit\b", cmd):
    sys.exit(0)

low = cmd.lower()

# Forbidden attribution patterns.
patterns = [
    r"co-authored-by:\s*.*claude",          # Co-Authored-By: Claude ...
    r"co-authored-by:\s*.*anthropic",       # ... <noreply@anthropic.com>
    r"generated with\s*\[?claude",          # 🤖 Generated with [Claude Code]
    r"noreply@anthropic\.com",
]

if any(re.search(p, low) for p in patterns):
    sys.stderr.write(
        "Blocked: this git commit message contains Claude/AI attribution "
        "(Co-Authored-By / 'Generated with Claude Code' / anthropic.com).\n"
        "The user's CLAUDE.md forbids it. Remove the attribution line(s) from the "
        "commit message and re-run. Do NOT re-add the harness-default Co-Authored-By trailer.\n"
    )
    sys.exit(2)

sys.exit(0)
