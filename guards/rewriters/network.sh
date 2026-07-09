# Network (curl/wget) → rtk. args: match_cmd cmd_body env_prefix.
rewrite_network() {
  local m="$1" body="$2" env="$3"
  if echo "$m" | grep -qE '^curl[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed 's/^curl /rtk curl /')"
  elif echo "$m" | grep -qE '^wget[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed 's/^wget /rtk wget /')"
  fi
}

# order: 70
register_rewriter 70 rewrite_network
