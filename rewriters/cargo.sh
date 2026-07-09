# cargo → rtk. args: match_cmd cmd_body env_prefix.
rewrite_cargo() {
  local m="$1" body="$2" env="$3" sub
  echo "$m" | grep -qE '^cargo[[:space:]]' || return 0
  sub=$(echo "$m" | sed -E 's/^cargo[[:space:]]+(\+[^[:space:]]+[[:space:]]+)?//')
  case "$sub" in
    test|test\ *|build|build\ *|clippy|clippy\ *|check|check\ *|install|install\ *|fmt|fmt\ *)
      echo "${env}rtk $body" ;;
  esac
}

# order: 30
register_rewriter 30 rewrite_cargo
