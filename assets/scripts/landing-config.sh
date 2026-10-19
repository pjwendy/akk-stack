#!/usr/bin/env bash
# Writes the landing page's list of services (data/landing/links.json) from .env, so it only shows
# what is enabled. Run by `make up` (and `make landing-config`). Links are ports and paths; the page
# builds full URLs from the host it was opened on. Add your own links in data/landing/links.local.json
# (same shape, not in git): {"groups": [{"title": "...", "links": [{"name": "...", "port": 1234, ...}]}]}
set -euo pipefail

out="${DATA_PATH_HOST:-./data}/landing"
mkdir -p "$out"

on() { [ "${1:-false}" = "true" ]; }
link() { # name port description [path] [scheme]
  printf '        {"name": "%s", "port": %s, "path": "%s", "scheme": "%s", "description": "%s"}' "$1" "$2" "${4:-/}" "${5:-http}" "$3"
}

{
  echo '{'
  echo '  "title": "EQEmu Server",'
  echo '  "generated": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",'
  echo '  "groups": ['
  echo '    {"title": "Administration", "links": ['
  items=()
  items+=("$(link "EQEmu Admin (Spire)" 3000 "Server administration, rules, content and logs")")
  on "${ENABLE_PEQ_EDITOR:-false}" && items+=("$(link "PEQ Editor" 8081 "Edit NPCs, spawns, loot, merchants and quests' data")")
  on "${ENABLE_PHPMYADMIN:-false}" && items+=("$(link "phpMyAdmin" 8082 "The database, table by table")")
  if on "${SPIRE_DEV:-false}"; then
    items+=("$(link "Spire backend (dev)" 3010 "Spire development backend")")
    items+=("$(link "Spire frontend (dev)" 8080 "Spire development frontend")")
  fi
  (IFS=$'\n'; echo "${items[*]}" | sed '$!s/$/,/')
  echo '    ]},'
  echo '    {"title": "For players", "links": ['
  items=()
  on "${ENABLE_CHARBROWSER:-false}" && items+=("$(link "Character Browser" 8083 "Characters, their gear, guilds and bots")")
  on "${ENABLE_ALLAKHAZAM:-false}" && items+=("$(link "Allakhazam" 8084 "Item, NPC, zone and spell database")")
  on "${ENABLE_FTP_QUESTS:-false}" && items+=("$(link "Quests FTP" 21 "Upload quest scripts (user quests)" "/" "ftp")")
  (IFS=$'\n'; echo "${items[*]}" | sed '$!s/$/,/')
  echo '    ]}'
  echo '  ],'
  echo '  "game": {"login_port": 5998, "world_port": 9000}'
  echo '}'
} > "$out/links.json"

[ -f "$out/links.local.json" ] || echo '{"groups": []}' > "$out/links.local.json"
echo "Landing page links written to $out/links.json"
