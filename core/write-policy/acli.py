"""acli write policy. Copied verbatim from slackcli-guard.py. Returns 'ask'."""
import re

# [^|;&]* instead of .* to avoid false positives from piped commands
ACLI_WRITE = re.compile(
    r'\bacli\b[^|;&]*\b('
    r'workitem\s+(archive|unarchive|assign|clone|create|create-bulk|delete|edit|transition|link)'
    r'|workitem\s+comment\s+(add|delete|edit|update)'
    r'|workitem\s+attachment\s+(add|delete|upload)'
    r'|workitem\s+watcher\s+(add|remove)'
    r'|sprint\s+(create|delete|update)'
    r'|project\s+(archive|create|delete|restore|update)'
    r'|board\s+(create|delete)'
    r'|confluence\s+blog\s+create'
    r'|confluence\s+space\s+(archive|create|restore|update)'
    r'|auth\s+(login|logout|remove|revoke|add)'
    r'|admin\b'
    r'|rovodev\b'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bacli\b', cmd):
        return None
    if ACLI_WRITE.search(cmd):
        return ('ask', f'acli write — manual approval required: {cmd}')
    return None

ORDER = 30
