"""git commit attribution write policy. Ported from commit-attribution-guard.py."""
import re

GIT_COMMIT_INVOCATION = re.compile(r"\bgit\b[^\n]*\bcommit\b")

FORBIDDEN_PATTERNS = [
    re.compile(r"co-authored-by:\s*.*claude"),
    re.compile(r"co-authored-by:\s*.*anthropic"),
    re.compile(r"generated with\s*\[?claude"),
    re.compile(r"noreply@anthropic\.com"),
]


def check(cmd):
    if not GIT_COMMIT_INVOCATION.search(cmd):
        return None
    low = cmd.lower()
    if any(p.search(low) for p in FORBIDDEN_PATTERNS):
        return ('deny', f'commit attribution blocked: {cmd}')
    return None

ORDER = 100
