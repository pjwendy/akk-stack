#!/usr/bin/env bash
# Writes the landing page's list of services (data/landing/links.json) from .env, so it only shows
# what is enabled. Run by `make up` (and `make landing-config`). Links are ports and paths; the page
# builds full URLs from the host it was opened on. Add your own links in data/landing/links.local.json
# (same shape, not in git): {"groups": [{"title": "...", "links": [{"name": "...", "port": 1234, ...}]}]}
#
# With SHOW_LANDING_CREDENTIALS=true each link also carries its logins (from .env, and the EQEmu
# Admin password from the server's config). data/ isn't in git; keep LANDING_IP=127.0.0.1 then, so
# only this machine can open the page.
set -euo pipefail

out="${DATA_PATH_HOST:-./data}/landing"
mkdir -p "$out"

on() { [ "${1:-false}" = "true" ]; }
json() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "$s"; }
show_logins=false
on "${SHOW_LANDING_CREDENTIALS:-false}" && show_logins=true

# logins for a link: "label|user|password" ...
logins() {
  $show_logins || return 0
  local parts=() entry label user pass
  for entry in "$@"; do
    IFS='|' read -r label user pass <<< "$entry"
    parts+=("{\"label\": \"$(json "$label")\", \"user\": \"$(json "$user")\", \"password\": \"$(json "$pass")\"}")
  done
  (IFS=,; printf ', "logins": [%s]' "${parts[*]}")
}

link() { # name port description path scheme [logins...]
  local name=$1 port=$2 desc=$3 path=${4:-/} scheme=${5:-http}
  shift 5 || shift $#
  printf '        {"name": "%s", "port": %s, "path": "%s", "scheme": "%s", "description": "%s"%s}' \
    "$(json "$name")" "$port" "$path" "$scheme" "$(json "$desc")" "$(logins "$@")"
}

admin_password=""
if $show_logins; then
  admin_password=$(docker exec akk-stack-eqemu-server-1 bash -c "jq -r '.[\"web-admin\"].application.admin.password' ~/server/eqemu_config.json" 2>/dev/null || true)
  [ -n "$admin_password" ] && [ "$admin_password" != "null" ] || admin_password="${SPIRE_ADMIN_PASSWORD:-}"
fi

group() { # title, then lines
  local title=$1; shift
  echo "    {\"title\": \"$(json "$title")\", \"links\": ["
  (IFS=$'\n'; printf '%s\n' "$@" | sed '$!s/$/,/')
  echo "    ]}"
}

admin=()
admin+=("$(link "EQEmu Admin (Spire)" 3000 "Server administration, rules, content and logs" / http "Admin|admin|$admin_password")")
on "${ENABLE_PEQ_EDITOR:-false}" && admin+=("$(link "PEQ Editor" 8081 "Edit NPCs, spawns, loot, merchants and quests' data" / http \
  "Proxy (browser prompt)|${PEQ_EDITOR_PROXY_USERNAME:-peq-editor}|${PEQ_EDITOR_PROXY_PASSWORD:-}" "Editor|admin|${PEQ_EDITOR_PASSWORD:-}")")
on "${ENABLE_PHPMYADMIN:-false}" && admin+=("$(link "phpMyAdmin" 8082 "The database, table by table" / http \
  "Proxy (browser prompt)|${PHPMYADMIN_USERNAME:-admin}|${PHPMYADMIN_PASSWORD:-}" "Database|${MARIADB_USER:-eqemu}|${MARIADB_PASSWORD:-}")")
if on "${SPIRE_DEV:-false}"; then
  admin+=("$(link "Spire backend (dev)" 3010 "Spire development backend" / http)")
  admin+=("$(link "Spire frontend (dev)" 8080 "Spire development frontend" / http)")
fi

players=()
on "${ENABLE_CHARBROWSER:-false}" && players+=("$(link "Character Browser" 8083 "Characters, their gear, guilds and bots" / http)")
on "${ENABLE_ALLAKHAZAM:-false}" && players+=("$(link "Allakhazam" 8084 "Item, NPC, zone and spell database" / http)")
on "${ENABLE_FTP_QUESTS:-false}" && players+=("$(link "Quests FTP" 21 "Upload quest scripts" / ftp "FTP|quests|${FTP_QUESTS_PASSWORD:-}")")

access=()
access+=("$(link "MariaDB" 3306 "The server's database (mysql client, HeidiSQL, ...)" / mysql \
  "Server|${MARIADB_USER:-eqemu}|${MARIADB_PASSWORD:-}" "Root|root|${MARIADB_ROOT_PASSWORD:-}")")
access+=("$(link "Server shell (SSH)" 2224 "ssh eqemu@<host> -p 2224, into the eqemu-server container" / ssh \
  "SSH|eqemu|${SERVER_PASSWORD:-}")")

{
  echo '{'
  echo '  "title": "EQEmu Server",'
  echo '  "generated": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",'
  echo "  \"credentials\": $show_logins,"
  echo '  "groups": ['
  group "Administration" "${admin[@]}"
  echo '    ,'
  group "For players" "${players[@]+"${players[@]}"}"
  if $show_logins; then
    echo '    ,'
    group "Direct access" "${access[@]}"
  fi
  echo '  ],'
  echo '  "game": {"login_port": 5998, "world_port": 9000}'
  echo '}'
} > "$out/links.json"

[ -f "$out/links.local.json" ] || echo '{"groups": []}' > "$out/links.local.json"
echo "Landing page links written to $out/links.json$($show_logins && echo ' (with logins)')"
