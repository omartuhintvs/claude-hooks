"""hermes plugin — blocks commits to TVS org repos under a non-company email.

hermes fires `pre_tool_call` before dispatching a tool; returning {"action": "block"}
stops it. This shells out to the shared identity-guard.sh (same JSON contract as Claude
Code) and blocks on exit code 2. Install to ~/.hermes/plugins/tvs_identity_guard/.
"""
import json
import os
import re
import subprocess

GUARD = os.environ.get(
    "TVS_IDENTITY_GUARD",
    os.path.expanduser("~/.config/tvs-agent-shield/identity-guard.sh"),
)
# Only commit-creating git commands; push is covered by the git pre-push hook.
COMMITISH = re.compile(
    r"\bgit\b[^|&;]*\b(commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am)\b"
)


def register(ctx):
    ctx.register_hook("pre_tool_call", scan)


def scan(tool_name, args, *_, **__):
    if tool_name not in ("bash", "shell"):
        return {"action": "allow"}
    command = (args or {}).get("command", "") if isinstance(args, dict) else ""
    if not command or not COMMITISH.search(command):
        return {"action": "allow"}
    payload = json.dumps({"tool_input": {"command": command}, "cwd": os.getcwd()})
    try:
        proc = subprocess.run(
            [GUARD], input=payload, text=True, capture_output=True, timeout=5
        )
    except Exception:
        return {"action": "block", "message": "TVS identity guard unavailable — refusing commit."}
    # 0 = allow, 2 = policy block, anything else = crash. Fail closed on any non-zero.
    if proc.returncode != 0:
        return {"action": "block", "message": (proc.stderr or "TVS identity guard error — refusing commit.").strip()}
    return {"action": "allow"}
