"""psql/mysql destructive-SQL policy. Copied verbatim from slackcli-guard.py."""
import re

DB_INLINE_SQL = re.compile(
    r'\b(psql|mysql)\b[^|;&]*\s(-c|--command|-e)\s*[^|;&]*\b('
    r'DROP\s+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|FUNCTION|PROCEDURE|TRIGGER|SEQUENCE)'
    r'|TRUNCATE\b'
    r'|DELETE\s+FROM\b'
    r')',
    re.IGNORECASE
)


def check(cmd):
    if not re.search(r'\b(psql|mysql)\b', cmd):
        return None
    if DB_INLINE_SQL.search(cmd):
        return ('deny', f'destructive SQL blocked: {cmd}')
    return None

ORDER = 60
