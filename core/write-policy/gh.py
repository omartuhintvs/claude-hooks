"""gh CLI write policy. Copied verbatim from slackcli-guard.py."""
import re

# Two patterns: subcommand (anchored after gh) + api write (separate to avoid body-text FP).
GH_SUBCMD_WRITE = re.compile(
    r'\bgh\b(?:\s+--?\w[\w-]*)?\s+('
    r'repo\s+(archive|rename|transfer|delete|create)'
    r'|secret\s+(set|delete)'
    r'|variable\s+(set|delete)'
    r'|auth\s+(login|logout|refresh|setup-git)'
    r'|ssh-key\s+(add|delete)'
    r'|gpg-key\s+(add|delete)'
    r'|workflow\s+(disable|enable|run)'
    r'|run\s+(cancel|rerun)'
    r'|release\s+(create|delete|edit|upload|delete-asset)'
    r'|gist\s+(create|delete|edit)'
    r'|label\s+(create|delete|edit)'
    r'|milestone\s+(create|delete|edit)'
    r')',
    re.IGNORECASE
)

GH_API_WRITE = re.compile(
    r'\bgh\b[^|;&]*\bapi\b[^|;&]*'
    r'(-X\s*(POST|PUT|PATCH|DELETE)'
    r'|-X(POST|PUT|PATCH|DELETE)'
    r'|--method\s+(POST|PUT|PATCH|DELETE)'
    r'|--input\b)',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bgh\b', cmd):
        return None
    if GH_SUBCMD_WRITE.search(cmd) or GH_API_WRITE.search(cmd):
        return ('deny', f'gh write blocked: {cmd}')
    return None

ORDER = 40
