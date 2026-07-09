# JS/TS tooling → rtk. args: match_cmd cmd_body env_prefix.
rewrite_js_tooling() {
  local m="$1" body="$2" env="$3"
  if echo "$m" | grep -qE '^(pnpm[[:space:]]+)?(npx[[:space:]]+)?vitest([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(pnpm )?(npx )?vitest( run)?/rtk vitest run/')"
  elif echo "$m" | grep -qE '^pnpm[[:space:]]+test([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^pnpm test/rtk vitest run/')"
  elif echo "$m" | grep -qE '^npm[[:space:]]+test([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^npm test/rtk npm test/')"
  elif echo "$m" | grep -qE '^npm[[:space:]]+run[[:space:]]+'; then
    echo "${env}$(echo "$body" | sed 's/^npm run /rtk npm /')"
  elif echo "$m" | grep -qE '^(npx[[:space:]]+)?vue-tsc([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(npx )?vue-tsc/rtk tsc/')"
  elif echo "$m" | grep -qE '^pnpm[[:space:]]+tsc([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^pnpm tsc/rtk tsc/')"
  elif echo "$m" | grep -qE '^(npx[[:space:]]+)?tsc([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(npx )?tsc/rtk tsc/')"
  elif echo "$m" | grep -qE '^pnpm[[:space:]]+lint([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^pnpm lint/rtk lint/')"
  elif echo "$m" | grep -qE '^(npx[[:space:]]+)?eslint([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(npx )?eslint/rtk lint/')"
  elif echo "$m" | grep -qE '^(npx[[:space:]]+)?prettier([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(npx )?prettier/rtk prettier/')"
  elif echo "$m" | grep -qE '^(npx[[:space:]]+)?playwright([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(npx )?playwright/rtk playwright/')"
  elif echo "$m" | grep -qE '^pnpm[[:space:]]+playwright([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed 's/^pnpm playwright/rtk playwright/')"
  elif echo "$m" | grep -qE '^(npx[[:space:]]+)?prisma([[:space:]]|$)'; then
    echo "${env}$(echo "$body" | sed -E 's/^(npx )?prisma/rtk prisma/')"
  fi
}

# order: 50
register_rewriter 50 rewrite_js_tooling
