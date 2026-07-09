// Pure TVS identity policy — single source of truth for the JS adapters.
// No I/O, no side effects. Mirror of core/policy.sh and core/policy.py;
// core/vectors.json keeps all three in lock-step.

export const WORK_DOMAINS = /@(technovativesolutions\.co\.uk|digiprodpass\.com)$/i;
export const WORK_ORGS = /[:/](technovativesolutions|digiprodpass)\//i;
export const COMMIT_VERBS = /\bgit\b[^|&;]*\b(commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am)\b/;

// A whole email string is tested, so the $ anchor blocks suffix tricks
// (evil@technovativesolutions.co.uk.attacker.com won't match).
export const isWorkEmail = (email) => typeof email === "string" && WORK_DOMAINS.test(email);
export const urlIsWork = (url) => typeof url === "string" && WORK_ORGS.test(url);
export const isCommitCommand = (command) => typeof command === "string" && COMMIT_VERBS.test(command);
