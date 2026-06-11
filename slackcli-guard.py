#!/usr/bin/env python3
"""Write guard: slackcli, gogcli, acli, gh, gcloud, kubectl, psql/mysql,
   aws, docker, heroku, vercel, helm, supabase, ansible, rsync."""
import json, sys, re

data = json.load(sys.stdin)
cmd = data.get('tool_input', {}).get('command', '').strip()

def deny(reason):
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'deny',
            'permissionDecisionReason': reason,
        }
    }))
    sys.exit(0)

def allow():
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'allow',
        }
    }))

def ask(reason):
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'ask',
            'permissionDecisionReason': reason,
        }
    }))
    sys.exit(0)

# ── slackcli ──────────────────────────────────────────────────────────────────
SLACKCLI_WRITE = re.compile(
    r'slackcli\s+('
    r'messages\s+(send|delete|react|draft)'
    r'|conversations\s+(archive|delete)'
    r'|canvas\s+delete'
    r'|auth\s+(login|logout|remove|set-default|parse-curl|login-browser)'
    r')',
    re.IGNORECASE
)

if re.search(r'\bslackcli\b', cmd):
    if SLACKCLI_WRITE.search(cmd):
        deny(f'slackcli write blocked (read-only mode): {cmd}')
    allow()
    sys.exit(0)

# ── gogcli ────────────────────────────────────────────────────────────────────
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

if re.search(r'\bgog\b', cmd):
    if GOG_WRITE.search(cmd):
        deny(f'gogcli write blocked (read-only mode): {cmd}')
    allow()
    sys.exit(0)

# ── acli ──────────────────────────────────────────────────────────────────────
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

if re.search(r'\bacli\b', cmd):
    if ACLI_WRITE.search(cmd):
        ask(f'acli write — manual approval required: {cmd}')
    allow()
    sys.exit(0)

# ── gh CLI ────────────────────────────────────────────────────────────────────
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

if re.search(r'\bgh\b', cmd):
    if GH_SUBCMD_WRITE.search(cmd) or GH_API_WRITE.search(cmd):
        deny(f'gh write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── gcloud ────────────────────────────────────────────────────────────────────
GCLOUD_WRITE = re.compile(
    r'\bgcloud\b[^|;&]*\b('
    r'delete'
    r'|disable'
    r'|revoke'
    r'|remove-iam-policy-binding'
    r'|remove-members'
    r'|auth\s+(login|revoke)'
    r'|config\s+unset'
    r')',
    re.IGNORECASE
)

if re.search(r'\bgcloud\b', cmd):
    if GCLOUD_WRITE.search(cmd):
        deny(f'gcloud write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── kubectl ───────────────────────────────────────────────────────────────────
KUBECTL_WRITE = re.compile(
    r'\bkubectl\b[^|;&]*\b('
    r'delete'
    r'|drain'
    r'|cordon'
    r'|uncordon'
    r'|taint'
    r'|config\s+(use-context|set-context|set-cluster|set-credentials|delete-context|delete-cluster|unset)'
    r')',
    re.IGNORECASE
)

if re.search(r'\bkubectl\b', cmd):
    if KUBECTL_WRITE.search(cmd):
        deny(f'kubectl write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── psql / mysql ──────────────────────────────────────────────────────────────
DB_INLINE_SQL = re.compile(
    r'\b(psql|mysql)\b[^|;&]*\s(-c|--command|-e)\s*[^|;&]*\b('
    r'DROP\s+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|FUNCTION|PROCEDURE|TRIGGER|SEQUENCE)'
    r'|TRUNCATE\b'
    r'|DELETE\s+FROM\b'
    r')',
    re.IGNORECASE
)

if re.search(r'\b(psql|mysql)\b', cmd):
    if DB_INLINE_SQL.search(cmd):
        deny(f'destructive SQL blocked: {cmd}')
    allow()
    sys.exit(0)

# ── aws ───────────────────────────────────────────────────────────────────────
# delete-* covers: delete-bucket, delete-function, delete-stack, delete-table, etc.
AWS_WRITE = re.compile(
    r'\baws\b[^|;&]*\b('
    r'delete-\w+'
    r'|terminate-instances'
    r'|deregister-image'
    r'|detach-role-policy|detach-user-policy|detach-group-policy'
    r'|remove-user-from-group|remove-role-from-instance-profile'
    r'|s3\s+rb\b'
    r'|s3\s+rm\b.*--recursive'
    r')',
    re.IGNORECASE
)

if re.search(r'\baws\b', cmd):
    if AWS_WRITE.search(cmd):
        deny(f'aws write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── docker ────────────────────────────────────────────────────────────────────
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

if re.search(r'\bdocker\b', cmd):
    if DOCKER_WRITE.search(cmd):
        deny(f'docker write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── heroku ────────────────────────────────────────────────────────────────────
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

if re.search(r'\bheroku\b', cmd):
    if HEROKU_WRITE.search(cmd):
        deny(f'heroku write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── vercel CLI ────────────────────────────────────────────────────────────────
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

if re.search(r'\bvercel\b', cmd):
    if VERCEL_CLI_WRITE.search(cmd):
        deny(f'vercel write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── helm ──────────────────────────────────────────────────────────────────────
# install/upgrade go to settings.json ask. uninstall/rollback hard-blocked here.
HELM_WRITE = re.compile(
    r'\bhelm\b[^|;&]*\b('
    r'uninstall\b'
    r'|delete\b'
    r'|rollback\b'
    r'|repo\s+(add|remove|update)\b'
    r')',
    re.IGNORECASE
)

if re.search(r'\bhelm\b', cmd):
    if HELM_WRITE.search(cmd):
        deny(f'helm write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── supabase ──────────────────────────────────────────────────────────────────
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

if re.search(r'\bsupabase\b', cmd):
    if SUPABASE_WRITE.search(cmd):
        deny(f'supabase write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── ansible ───────────────────────────────────────────────────────────────────
# ansible-playbook always blocked. Ad-hoc: block execution modules.
ANSIBLE_WRITE = re.compile(
    r'\bansible-playbook\b'
    r'|\bansible\b[^|;&]*\s+-m\s+(command|shell|raw|script|reboot|service|systemd)\b',
    re.IGNORECASE
)

if re.search(r'\bansible(-playbook)?\b', cmd):
    if ANSIBLE_WRITE.search(cmd):
        deny(f'ansible write blocked: {cmd}')
    allow()
    sys.exit(0)

# ── rsync ─────────────────────────────────────────────────────────────────────
if re.search(r'\brsync\b', cmd):
    if re.search(r'\brsync\b[^|;&]*--delete\b', cmd, re.IGNORECASE):
        deny(f'rsync --delete blocked: {cmd}')
    allow()
    sys.exit(0)

allow()
