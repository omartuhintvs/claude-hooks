"""slackcli write policy. Copied verbatim from slackcli-guard.py."""
import re

SLACKCLI_WRITE = re.compile(
    r'slackcli\s+('
    r'messages\s+(send|delete|react|draft)'
    r'|conversations\s+(archive|delete)'
    r'|canvas\s+delete'
    r'|auth\s+(login|logout|remove|set-default|parse-curl|login-browser)'
    r')',
    re.IGNORECASE
)


def check(cmd):
    """Return (decision, reason) or None. decision in {'deny','ask'}."""
    if not re.search(r'\bslackcli\b', cmd):
        return None
    if SLACKCLI_WRITE.search(cmd):
        return ('deny', f'slackcli write blocked (read-only mode): {cmd}')
    return None

ORDER = 10
