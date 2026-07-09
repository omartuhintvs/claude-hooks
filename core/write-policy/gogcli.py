"""gogcli write policy. Copied verbatim from slackcli-guard.py."""
import re

# [^|;&]* instead of .* to avoid false positives from piped commands
GOG_WRITE = re.compile(
    r'\bgog\b[^|;&]*\b('
    r'send|upload|up\b|put\b|login'
    r'|gmail\s+(send|reply|forward|delete|archive|move|mark|star|unstar|create|update|trash|drafts\s+(send|create|update|delete)|filters\s+(create|delete)|labels\s+(create|delete|update))'
    r'|drive\s+(upload|delete|trash|move|rename|mkdir|copy|permissions|share|create)'
    r'|cal(endar)?\s+(create|add|update|delete|remove|rsvp|respond)'
    r'|contacts?\s+(create|add|update|delete|remove)'
    r'|tasks?\s+(create|add|update|delete|remove|complete|reopen)'
    r'|chat\s+send'
    r'|keep\s+(create|add|update|delete|archive|pin|unpin|label)'
    r'|sheets?\s+(write|append|update|create|delete|clear|import)'
    r'|auth\s+(add|remove|revoke|login)'
    r'|admin\s+(create|update|delete|add|remove|suspend|restore|reset)'
    r'|appscript\s+(run|deploy|create|update|delete)'
    r'|forms?\s+(create|update|delete)'
    r'|groups?\s+(create|update|delete|add|remove)'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\bgog\b', cmd):
        return None
    if GOG_WRITE.search(cmd):
        return ('deny', f'gogcli write blocked (read-only mode): {cmd}')
    return None

ORDER = 20
