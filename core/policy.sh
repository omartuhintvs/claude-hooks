#!/bin/bash
# Pure TVS identity policy — the single source of truth for the bash guards.
# No I/O, no side effects: every function takes strings and returns a status/prints.
# Sourced by guards/identity-guard.sh and guards/git-hooks/_dispatch. Mirror of
# core/policy.mjs and core/policy.py; core/vectors.json keeps all three in lock-step.

# A single extracted email token is matched whole, so the $ anchor is safe against
# suffix tricks (evil@technovativesolutions.co.uk.attacker.com won't match).
TVS_WORK_DOMAINS='@(technovativesolutions\.co\.uk|digiprodpass\.com)$'
TVS_WORK_ORGS='[:/](technovativesolutions|digiprodpass)/'
TVS_COMMIT_VERBS='commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am'
TVS_EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# tvs_is_work_email <email> -> exit 0 if it is a company address
tvs_is_work_email() { printf '%s' "$1" | grep -qiE "$TVS_WORK_DOMAINS"; }

# tvs_url_is_work <url> -> exit 0 if the URL is in a TVS org
tvs_url_is_work() { printf '%s' "$1" | grep -qiE "$TVS_WORK_ORGS"; }

# tvs_is_commit_cmd <command> -> exit 0 if it is a commit-creating git command
tvs_is_commit_cmd() { printf '%s' "$1" | grep -qE "\bgit\b[^|&;]*\b($TVS_COMMIT_VERBS)\b"; }

# tvs_assigned_emails <command> -> print identity-assignment emails, one per line
# (never emails that merely appear in a commit message).
tvs_assigned_emails() {
  printf '%s' "$1" | grep -oiE "(user\.email=|GIT_AUTHOR_EMAIL=|GIT_COMMITTER_EMAIL=)$TVS_EMAIL" | grep -oiE "$TVS_EMAIL"
  printf '%s' "$1" | grep -oiE -- "--author[= ]+\"?[^\"]*\"?" | grep -oiE "$TVS_EMAIL"
}
