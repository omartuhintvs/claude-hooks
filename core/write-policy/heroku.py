"""heroku write policy. Copied verbatim from slackcli-guard.py."""
import re

HEROKU_WRITE = re.compile(
    r'\bheroku\b[^|;&]*\b('
    r'apps?\s*:\s*destroy'
    r'|destroy\b'
    r'|pg\s*:\s*(reset|destroy|unfollow)'
    r'|config\s*:\s*(set|unset)\b'
    r'|addons?\s*:\s*(destroy|remove)\b'
    r'|pipelines?\s*:\s*destroy'
    r'|spaces?\s*:\s*destroy'
    r'|releases?\s*:\s*rollback'
    r'|auth[:\s]+(login|logout|token)'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bheroku\b', cmd):
        return None
    if HEROKU_WRITE.search(cmd):
        return ('deny', f'heroku write blocked: {cmd}')
    return None

ORDER = 90
