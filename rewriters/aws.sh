# aws CLI → rtk aws. args: match_cmd cmd_body env_prefix.
rewrite_aws() {
  local m="$1" body="$2" env="$3"
  echo "$m" | grep -qE '^aws[[:space:]]+' || return 0
  echo "${env}$(echo "$body" | sed 's/^aws /rtk aws /')"
}

# order: 110
register_rewriter 110 rewrite_aws
