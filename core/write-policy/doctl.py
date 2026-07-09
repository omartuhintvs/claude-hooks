"""doctl CLI write policy. Ported from doctl-guard.py."""
import re

DOCTL_INVOCATION = re.compile(r"(?:^|[\s;&|()`$])doctl\b")


def check(cmd):
    if DOCTL_INVOCATION.search(cmd):
        return ('deny', f'doctl blocked: {cmd}')
    return None

ORDER = 100
