"""ansible write policy. Copied verbatim from slackcli-guard.py."""
import re

# ansible-playbook always blocked. Ad-hoc: block execution modules.
ANSIBLE_WRITE = re.compile(
    r'\bansible-playbook\b'
    r'|\bansible\b[^|;&]*\s+-m\s+(command|shell|raw|script|reboot|service|systemd)\b',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bansible(-playbook)?\b', cmd):
        return None
    if ANSIBLE_WRITE.search(cmd):
        return ('deny', f'ansible write blocked: {cmd}')
    return None

ORDER = 130
