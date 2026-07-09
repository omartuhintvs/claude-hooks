"""rsync write policy. Copied verbatim from slackcli-guard.py."""
import re


def check(cmd):
    if not re.search(r'\brsync\b', cmd):
        return None
    if re.search(r'\brsync\b[^|;&]*--delete\b', cmd, re.IGNORECASE):
        return ('deny', f'rsync --delete blocked: {cmd}')
    return None

ORDER = 140
