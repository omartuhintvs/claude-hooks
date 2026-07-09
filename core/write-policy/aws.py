"""aws write policy. Copied verbatim from slackcli-guard.py."""
import re

# delete-* covers: delete-bucket, delete-function, delete-stack, delete-table, etc.
AWS_WRITE = re.compile(
    r'\baws\b[^|;&]*\b('
    r'delete-\w+'
    r'|terminate-instances'
    r'|deregister-image'
    r'|detach-role-policy|detach-user-policy|detach-group-policy'
    r'|remove-user-from-group|remove-role-from-instance-profile'
    r'|s3\s+rb\b'
    r'|s3\s+rm\b.*--recursive'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\baws\b', cmd):
        return None
    if AWS_WRITE.search(cmd):
        return ('deny', f'aws write blocked: {cmd}')
    return None

ORDER = 70
