"""supabase write policy. Copied verbatim from slackcli-guard.py."""
import re

# db push (migrations) goes to settings.json ask. db reset hard-blocked here.
SUPABASE_WRITE = re.compile(
    r'\bsupabase\b[^|;&]*\b('
    r'db\s+reset\b'
    r'|projects?\s+delete\b'
    r'|orgs?\s+delete\b'
    r'|secrets?\s+(set|unset|delete)\b'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bsupabase\b', cmd):
        return None
    if SUPABASE_WRITE.search(cmd):
        return ('deny', f'supabase write blocked: {cmd}')
    return None

ORDER = 120
