# pnpm package mgmt (list/ls/outdated) → rtk pnpm. args: match_cmd cmd_body env_prefix.
rewrite_pnpm() {
  local m="$1" body="$2" env="$3"
  echo "$m" | grep -qE '^pnpm[[:space:]]+(list|ls|outdated)([[:space:]]|$)' || return 0
  echo "${env}$(echo "$body" | sed 's/^pnpm /rtk pnpm /')"
}

# order: 80
register_rewriter 80 rewrite_pnpm
