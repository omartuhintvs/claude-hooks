"""psql/mysql destructive-SQL policy. Copied verbatim from slackcli-guard.py."""
import re

# Match a destructive keyword anywhere in the psql/mysql invocation, not just
# after -c/-e. This also covers heredoc (`psql db <<SQL ... DROP TABLE ...`)
# and pasted multi-statement bodies where no inline-SQL flag is present.
# The keyword shapes stay specific (DROP <object>, TRUNCATE, DELETE FROM) so a
# harmless `SELECT * FROM dropbox_events` doesn't trip it.
DB_INLINE_SQL = re.compile(
    r'\b(psql|mysql)\b[^|;&]*\b('
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
