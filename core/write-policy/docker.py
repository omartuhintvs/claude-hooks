"""docker write policy. Copied verbatim from slackcli-guard.py."""
import re

# \srm\b matches rm as subcommand but not --rm flag (which has - not space before rm).
DOCKER_WRITE = re.compile(
    r'\bdocker\b[^|;&]*('
    r'\srm\b'
    r'|system\s+prune'
    r'|volume\s+(rm|prune)'
    r'|network\s+(rm|prune)'
    r'|container\s+(rm|prune)'
    r'|image\s+(rm|prune)'
    r'|rmi\b'
    r'|stack\s+(rm|remove|down)'
    r'|service\s+(rm|remove)'
    r'|swarm\s+(leave|init)'
    r'|compose\s+down\b'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bdocker\b', cmd):
        return None
    if DOCKER_WRITE.search(cmd):
        return ('deny', f'docker write blocked: {cmd}')
    return None

ORDER = 80
