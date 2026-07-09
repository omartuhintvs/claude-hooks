"""gcloud write policy. Copied verbatim from slackcli-guard.py."""
import re

GCLOUD_WRITE = re.compile(
    r'\bgcloud\b[^|;&]*\b('
    r'delete'
    r'|disable'
    r'|revoke'
    r'|remove-iam-policy-binding'
    r'|remove-members'
    r'|auth\s+(login|revoke)'
    r'|config\s+unset'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bgcloud\b', cmd):
        return None
    if GCLOUD_WRITE.search(cmd):
        return ('deny', f'gcloud write blocked: {cmd}')
    return None

ORDER = 50
