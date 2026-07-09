# psql → rtk psql. args: match_cmd cmd_body env_prefix.
rewrite_psql() {
  local m="$1" body="$2" env="$3"
  echo "$m" | grep -qE '^psql([[:space:]]|$)' || return 0
  echo "${env}$(echo "$body" | sed 's/^psql/rtk psql/')"
}

# order: 120
register_rewriter 120 rewrite_psql
