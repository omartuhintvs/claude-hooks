# Go tooling → rtk. args: match_cmd cmd_body env_prefix.
rewrite_go() {
  local m="$1" body="$2" env="$3"
  if echo "$m" | grep -qE '^go[[:space:]]+test([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^go test/rtk go test/')"
  elif echo "$m" | grep -qE '^go[[:space:]]+build([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^go build/rtk go build/')"
  elif echo "$m" | grep -qE '^go[[:space:]]+vet([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^go vet/rtk go vet/')"
  elif echo "$m" | grep -qE '^golangci-lint([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^golangci-lint/rtk golangci-lint/')"
  fi
}

# order: 100
register_rewriter 100 rewrite_go
