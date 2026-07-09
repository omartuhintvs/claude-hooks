# File ops (cat/grep/ls/tree/find/diff/head) → rtk. args: match_cmd cmd_body env_prefix.
rewrite_files() {
  local m="$1" body="$2" env="$3"
  if echo "$m" | grep -qE '^cat[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed 's/^cat /rtk read /')"
  elif echo "$m" | grep -qE '^(rg|grep)[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed -E 's/^(rg|grep) /rtk grep /')"
  elif echo "$m" | grep -qE '^ls([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^ls/rtk ls/')"
  elif echo "$m" | grep -qE '^tree([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^tree/rtk tree/')"
  elif echo "$m" | grep -qE '^find[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed 's/^find /rtk find /')"
  elif echo "$m" | grep -qE '^diff[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed 's/^diff /rtk diff /')"
  elif echo "$m" | grep -qE '^head[[:space:]]+'; then
    # head -N file → rtk read file --max-lines N ; also head --lines=N file
    local lines file
    if echo "$m" | grep -qE '^head[[:space:]]+-[0-9]+[[:space:]]+'; then
      lines=$(echo "$m" | sed -E 's/^head +-([0-9]+) +.+$/\1/')
      file=$(echo "$m" | sed -E 's/^head +-[0-9]+ +(.+)$/\1/')
      echo "${env}rtk read $file --max-lines $lines"
    elif echo "$m" | grep -qE '^head[[:space:]]+--lines=[0-9]+[[:space:]]+'; then
      lines=$(echo "$m" | sed -E 's/^head +--lines=([0-9]+) +.+$/\1/')
      file=$(echo "$m" | sed -E 's/^head +--lines=[0-9]+ +(.+)$/\1/')
      echo "${env}rtk read $file --max-lines $lines"
    fi
  fi
}

# order: 40
register_rewriter 40 rewrite_files
