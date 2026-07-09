# Python tooling → rtk. args: match_cmd cmd_body env_prefix.
rewrite_python() {
  local m="$1" body="$2" env="$3"
  if echo "$m" | grep -qE '^pytest([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^pytest/rtk pytest/')"
  elif echo "$m" | grep -qE '^python[[:space:]]+-m[[:space:]]+pytest([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^python -m pytest/rtk pytest/')"
  elif echo "$m" | grep -qE '^ruff[[:space:]]+(check|format)([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^ruff /rtk ruff /')"
  elif echo "$m" | grep -qE '^pip[[:space:]]+(list|outdated|install|show)([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^pip /rtk pip /')"
  elif echo "$m" | grep -qE '^uv[[:space:]]+pip[[:space:]]+(list|outdated|install|show)([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^uv pip /rtk pip /')"
  elif echo "$m" | grep -qE '^mypy([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^mypy/rtk mypy/')"
  elif echo "$m" | grep -qE '^python[[:space:]]+-m[[:space:]]+mypy([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^python -m mypy/rtk mypy/')"
  fi
}

# order: 90
register_rewriter 90 rewrite_python
