# gh CLI → rtk gh. args: match_cmd cmd_body env_prefix.
rewrite_gh() {
  local m="$1" body="$2" env="$3"
  echo "$m" | grep -qE '^gh[[:space:]]+(pr|issue|run|api|release)([[:space:]]|$)' || return 0
  echo "${env}$(echo "$body" | sed 's/^gh /rtk gh /')"
}

# order: 20
register_rewriter 20 rewrite_gh
