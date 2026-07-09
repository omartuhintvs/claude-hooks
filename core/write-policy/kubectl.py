"""kubectl (and `kc` alias) write policy. Ported from kubectl-guard.py."""
import re

KUBECTL_INVOCATION = re.compile(r"(?:^|[\s;&|()`$])(?:kubectl|kc)\b")

DESTRUCTIVE = (
    r"delete|drain|cordon|uncordon|taint|replace|patch|scale|edit|apply|"
    r"create|set|annotate|label|expose|autoscale|"
    r"rollout\s+(?:restart|undo)"
)

KUBECTL_DESTRUCTIVE = re.compile(
    r"(?:^|[\s;&|()`$])(?:kubectl|kc)\b[^;&|<>]*?\b(?:" + DESTRUCTIVE + r")\b"
)


def check(cmd):
    if not KUBECTL_INVOCATION.search(cmd):
        return None
    if KUBECTL_DESTRUCTIVE.search(cmd):
        return ('deny', f'kubectl blocked: {cmd}')
    return None

ORDER = 100
