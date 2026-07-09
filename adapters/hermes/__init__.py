"""hermes plugin — runs the full TVS guard chain (write-policy + identity + push) on
every bash/shell command.

hermes fires `pre_tool_call` before dispatching a tool; returning {"action": "block"}
stops it. This shells out to the shared guard-all.sh (same JSON contract as Claude
Code) and blocks on deny/ask decisions. Install to ~/.hermes/plugins/tvs_identity_guard/.
"""
import json
import os
import re
import subprocess

try:
    from .policy import is_commit_command
except ImportError:
    from policy import is_commit_command

GUARD = os.environ.get(
    "TVS_GUARD_ALL",
    os.path.expanduser("~/.config/tvs-agent-shield/guards/guard-all.sh"),
)

_PUSH_RE = re.compile(r"\bgit\b[^|&;]*\bpush(\s|$)")


def _is_push_command(command):
    return bool(_PUSH_RE.search(command))


def register(ctx):
    ctx.register_hook("pre_tool_call", scan)


def scan(tool_name, args, *_, **__):
    if tool_name not in ("bash", "shell"):
        return {"action": "allow"}
    command = (args or {}).get("command", "") if isinstance(args, dict) else ""
    if not command:
        return {"action": "allow"}
    payload = json.dumps({"tool_input": {"command": command}, "cwd": os.getcwd()})
    try:
        proc = subprocess.run(
            [GUARD], input=payload, text=True, capture_output=True, timeout=5
        )
    except Exception:
        if is_commit_command(command) or _is_push_command(command):
            return {"action": "block", "message": "TVS guard unavailable — refusing commit/push (fail-closed)."}
        return {"action": "allow"}
    try:
        decision = json.loads(proc.stdout or "{}").get("hookSpecificOutput", {}).get("permissionDecision")
    except Exception:
        decision = None
    if decision in ("deny", "ask"):
        return {"action": "block", "message": (proc.stderr or f"TVS guard: {decision}.").strip()}
    # Malformed/empty stdout must not downgrade a real deny: guard-all exits 2 on block.
    # Honor the exit code as the fallback signal (mirrors bridges/guard-check.mjs).
    if decision is None and proc.returncode == 2:
        return {"action": "block", "message": (proc.stderr or "TVS guard: blocked.").strip()}
    # ponytail: rtk rewriting is best-effort only. hermes's scan() return contract here
    # only supports {"action": ...}; there is no confirmed "modified_args" mutation API in
    # this codebase's hermes hook contract, so we do NOT fabricate one — rewrite is a no-op
    # for hermes (blocks above still apply).
    return {"action": "allow"}
