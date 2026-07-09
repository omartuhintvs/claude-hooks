"""Pure TVS identity policy — single source of truth for the Python adapter (hermes).

No I/O, no side effects. Mirror of core/policy.sh and core/policy.mjs; core/vectors.json
keeps all three in lock-step.
"""
import re

WORK_DOMAINS = re.compile(r"@(technovativesolutions\.co\.uk|digiprodpass\.com)$", re.I)
WORK_ORGS = re.compile(r"[:/](technovativesolutions|digiprodpass)/", re.I)
# A whole email string is tested, so the $ anchor blocks suffix tricks.
COMMIT_VERBS = re.compile(
    r"\bgit\b[^|&;]*\b(commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am)\b"
)


def is_work_email(email):
    return bool(email) and WORK_DOMAINS.search(email) is not None


def url_is_work(url):
    return bool(url) and WORK_ORGS.search(url) is not None


def is_commit_command(command):
    return bool(command) and COMMIT_VERBS.search(command) is not None
