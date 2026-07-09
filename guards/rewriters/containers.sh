# Containers (docker/kubectl) → rtk. args: match_cmd cmd_body env_prefix.
rewrite_containers() {
  local m="$1" body="$2" env="$3" sub
  if echo "$m" | grep -qE '^docker[[:space:]]'; then
    if echo "$m" | grep -qE '^docker[[:space:]]+compose([[:space:]]|$)'; then
      sub=$(echo "$m" | sed -E 's/^docker[[:space:]]+compose[[:space:]]*//')
      case "$sub" in
        ps|ps\ *|logs|logs\ *|build|build\ *)
          echo "${env}$(echo "$body" | sed 's/^docker /rtk docker /')" ;;
      esac
    else
      sub=$(echo "$m" | sed -E \
        -e 's/^docker[[:space:]]+//' \
        -e 's/(-H|--context|--config)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
        -e 's/--[a-z-]+=[^[:space:]]+[[:space:]]*//g' \
        -e 's/^[[:space:]]+//')
      case "$sub" in
        ps|ps\ *|images|images\ *|logs|logs\ *|run|run\ *|build|build\ *|exec|exec\ *)
          echo "${env}$(echo "$body" | sed 's/^docker /rtk docker /')" ;;
      esac
    fi
  elif echo "$m" | grep -qE '^kubectl[[:space:]]'; then
    sub=$(echo "$m" | sed -E \
      -e 's/^kubectl[[:space:]]+//' \
      -e 's/(--context|--kubeconfig|--namespace|-n)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
      -e 's/--[a-z-]+=[^[:space:]]+[[:space:]]*//g' \
      -e 's/^[[:space:]]+//')
    case "$sub" in
      get|get\ *|logs|logs\ *|describe|describe\ *|apply|apply\ *)
        echo "${env}$(echo "$body" | sed 's/^kubectl /rtk kubectl /')" ;;
    esac
  fi
}

# order: 60
register_rewriter 60 rewrite_containers
