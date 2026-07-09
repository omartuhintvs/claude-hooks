#!/usr/bin/env python3
"""Write guard dispatcher. Replaces slackcli-guard.py.

Auto-discovers per-CLI checkers in core/write-policy/ (drop-in plugins): each
module exposes check(cmd) and an ORDER = N priority. Runs them by (ORDER,
filename); first returning a decision wins."""
import glob
import importlib.util
import json
import os
import sys

# Locate the write-policy checker dir both in-repo (../core/write-policy) and
# installed (./write-policy, copied next to this dispatcher in ~/.claude/hooks/).
_here = os.path.dirname(os.path.abspath(__file__))
for _cand in (os.path.join(_here, 'write-policy'),
              os.path.join(_here, '..', 'core', 'write-policy')):
    if os.path.isdir(_cand):
        _policy_dir = _cand
        break
else:
    _policy_dir = None


def _load_registry():
    """Glob write-policy/*.py, load each, keep those exposing check(). Sort by
    (ORDER, filename). New tool = drop a file in the dir; nothing here changes."""
    mods = []
    for path in glob.glob(os.path.join(_policy_dir, '*.py')):
        name = os.path.basename(path)
        if name.startswith('_') or name.startswith('__'):
            continue
        spec = importlib.util.spec_from_file_location(name[:-3], path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        if hasattr(mod, 'check'):
            mods.append((getattr(mod, 'ORDER', 100), name, mod))
    mods.sort(key=lambda t: (t[0], t[1]))
    return [m for _, _, m in mods]


REGISTRY = _load_registry() if _policy_dir else []


def deny(reason):
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason,
    }}))
    sys.exit(0)


def ask(reason):
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'ask',
        'permissionDecisionReason': reason,
    }}))
    sys.exit(0)


def allow():
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'allow',
    }}))
    sys.exit(0)


def main():
    data = json.load(sys.stdin)
    cmd = data.get('tool_input', {}).get('command', '').strip()
    for mod in REGISTRY:
        result = mod.check(cmd)
        if result is None:
            continue
        decision, reason = result
        (deny if decision == 'deny' else ask)(reason)
    allow()


if __name__ == '__main__':
    main()
