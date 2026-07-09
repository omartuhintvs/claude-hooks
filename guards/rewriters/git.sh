# git → rtk. args: match_cmd cmd_body env_prefix. Echoes rewrite or nothing.
rewrite_git() {
  local m="$1" body="$2" env="$3" sub
  echo "$m" | grep -qE '^git[[:space:]]' || return 0
  sub=$(echo "$m" | sed -E \
    -e 's/^git[[:space:]]+//' \
    -e 's/(-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
    -e 's/--[a-z-]+=[^[:space:]]+[[:space:]]*//g' \
    -e 's/--(no-pager|no-optional-locks|bare|literal-pathspecs)[[:space:]]*//g' \
    -e 's/^[[:space:]]+//')
  case "$sub" in
    status|status\ *|diff|diff\ *|log|log\ *|add|add\ *|commit|commit\ *|push|push\ *|pull|pull\ *|branch|branch\ *|fetch|fetch\ *|stash|stash\ *|show|show\ *)
      echo "${env}rtk $body" ;;
  esac
}

# order: 10
register_rewriter 10 rewrite_git
