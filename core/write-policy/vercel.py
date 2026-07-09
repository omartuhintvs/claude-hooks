"""vercel CLI write policy. Copied verbatim from slackcli-guard.py."""
import re

# --prod (production deploy) and destructive ops blocked.
# Plain `vercel deploy` (preview) handled by settings.json ask rule.
VERCEL_CLI_WRITE = re.compile(
    r'\bvercel\b[^|;&]*('
    r'remove\b'
    r'|rm\b'
    r'|--prod\b'
    r'|env\s+(rm|remove)\b'
    r'|domains?\s+(rm|remove)\b'
    r'|dns\s+(rm|remove)\b'
    r'|certs?\s+(rm|remove)\b'
    r'|projects?\s+(rm|remove)\b'
    r'|teams?\s+delete\b'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bvercel\b', cmd):
        return None
    if VERCEL_CLI_WRITE.search(cmd):
        return ('deny', f'vercel write blocked: {cmd}')
    return None

ORDER = 100
