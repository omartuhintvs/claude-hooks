"""helm write policy. Copied verbatim from slackcli-guard.py."""
import re

# install/upgrade go to settings.json ask. uninstall/rollback hard-blocked here.
HELM_WRITE = re.compile(
    r'\bhelm\b[^|;&]*\b('
    r'uninstall\b'
    r'|delete\b'
    r'|rollback\b'
    r'|repo\s+(add|remove|update)\b'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bhelm\b', cmd):
        return None
    if HELM_WRITE.search(cmd):
        return ('deny', f'helm write blocked: {cmd}')
    return None

ORDER = 110
