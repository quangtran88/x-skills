#!/usr/bin/env bash
# scan-helpers.sh — sourced by inspect.sh

scan_http() {
  local root="$1"
  local items='[]'

  # docker-compose services with exposed ports
  if [[ -f "$root/docker-compose.yml" ]] || [[ -f "$root/docker-compose.yaml" ]]; then
    local compose_file
    compose_file=$([[ -f "$root/docker-compose.yml" ]] && echo "$root/docker-compose.yml" || echo "$root/docker-compose.yaml")
    local services
    # mikefarah yq v4 only does YAML/JSON marshalling; the object-construction is delegated to jq
    # (the plan's `yq eval '... map({...})'` is kislyuk/yq v3 syntax — incompatible with v4).
    services=$(yq eval -o=json '.' "$compose_file" 2>/dev/null \
      | jq '.services // {} | to_entries | map(select(.value.ports != null)) | map({name: .key, ports: .value.ports})' \
      || echo '[]')
    items=$(jq --argjson s "$services" '. + ($s | map({type: "http", source: "docker-compose", name: .name, ports: .ports, confidence: "high"}))' <<<"$items")
  fi

  # OpenAPI specs
  for f in openapi.yml openapi.yaml openapi.json swagger.yml swagger.yaml swagger.json; do
    if [[ -f "$root/$f" ]]; then
      items=$(jq --arg f "$f" '. + [{type: "http", source: "openapi", spec: $f, confidence: "high"}]' <<<"$items")
    fi
  done

  # package.json scripts that look like servers
  if [[ -f "$root/package.json" ]]; then
    local server_scripts
    server_scripts=$(jq -r '.scripts // {} | to_entries | map(select(.key | test("^(start|dev|serve)$"))) | tojson' "$root/package.json")
    items=$(jq --argjson s "$server_scripts" '. + ($s | map({type: "http", source: "npm-script", script: .key, command: .value, confidence: "medium"}))' <<<"$items")
  fi

  # Framework hints (presence of well-known files)
  local framework_files=("next.config.js" "nuxt.config.js" "src/server.ts" "src/index.ts" "main.py" "app.py" "main.go")
  for f in "${framework_files[@]}"; do
    if [[ -f "$root/$f" ]]; then
      items=$(jq --arg f "$f" '. + [{type: "http", source: "framework-file", file: $f, confidence: "low"}]' <<<"$items")
    fi
  done

  echo "$items"
}

scan_cli() {
  local root="$1"
  local items='[]'

  # package.json bin field
  if [[ -f "$root/package.json" ]]; then
    local bins
    bins=$(jq -r '.bin // {} | to_entries | tojson' "$root/package.json")
    items=$(jq --argjson b "$bins" '. + ($b | map({type: "cli", source: "package-bin", name: .key, command: .value, confidence: "high"}))' <<<"$items")
  fi

  # Go cmd/ subdirs
  if [[ -d "$root/cmd" ]]; then
    while IFS= read -r dir; do
      local name
      name=$(basename "$dir")
      items=$(jq --arg n "$name" --arg d "$dir" '. + [{type: "cli", source: "go-cmd", name: $n, dir: $d, confidence: "high"}]' <<<"$items")
    done < <(find "$root/cmd" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  fi

  echo "$items"
}

scan_grpc() {
  local root="$1"
  local items='[]'
  while IFS= read -r f; do
    items=$(jq --arg f "$f" '. + [{type: "grpc", source: "proto-file", spec: $f, confidence: "high"}]' <<<"$items")
  done < <(find "$root" -name '*.proto' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -20)
  echo "$items"
}

scan_graphql() {
  local root="$1"
  local items='[]'
  for f in schema.graphql schema.gql; do
    while IFS= read -r found; do
      items=$(jq --arg f "$found" '. + [{type: "graphql", source: "schema-file", spec: $f, confidence: "high"}]' <<<"$items")
    done < <(find "$root" -name "$f" -not -path '*/node_modules/*' 2>/dev/null | head -10)
  done
  echo "$items"
}

scan_workers() {
  local root="$1"
  local items='[]'
  # Look for queue library imports
  if grep -rqE "(bullmq|sidekiq|celery|@nestjs/bull)" "$root/src" "$root/app" 2>/dev/null; then
    items=$(jq '. + [{type: "worker", source: "queue-library", confidence: "medium"}]' <<<"$items")
  fi
  echo "$items"
}

scan_websocket() {
  local root="$1"
  local items='[]'
  if grep -rqE "(socket\.io|ws|websocket)" "$root/src" "$root/app" 2>/dev/null; then
    items=$(jq '. + [{type: "websocket", source: "ws-library", confidence: "medium"}]' <<<"$items")
  fi
  echo "$items"
}

scan_channels() {
  local root="$1"
  local items='[]'

  # Multiple exposed compose ports → candidate http channels
  if [[ -f "$root/docker-compose.yml" ]] || [[ -f "$root/docker-compose.yaml" ]]; then
    local compose_file
    compose_file=$([[ -f "$root/docker-compose.yml" ]] && echo "$root/docker-compose.yml" || echo "$root/docker-compose.yaml")
    local svc
    svc=$(yq eval -o=json '.' "$compose_file" 2>/dev/null \
      | jq '.services // {} | to_entries | map(select(.value.ports != null))
            | map({name: .key, driver:"http", audience:"user", entry_point:.key,
                   source:"compose-port", confidence:"medium"})' || echo '[]')
    items=$(jq --argjson s "$svc" '. + $s' <<<"$items")
  fi

  # Chat-bot SDK imports → candidate computer-use chat channels.
  # Format: "<grep-alt-pattern>|<channel-name>" (bash 3.2: no assoc arrays).
  for probe in \
    'telegraf|node-telegram-bot-api|python-telegram-bot::telegram' \
    'whatsapp-web|@whiskeysockets/baileys|twilio::whatsapp' \
    'discord\.js|discord\.py::discord'; do
    local pats="${probe%%::*}" cname="${probe##*::}"
    if grep -rqE "($pats)" "$root/src" "$root/app" "$root/package.json" 2>/dev/null; then
      items=$(jq --arg n "$cname" \
        '. + [{name:$n, driver:"computer-use", audience:"external",
               entry_point:"external", source:"bot-sdk", confidence:"low"}]' <<<"$items")
    fi
  done

  # Web-UI config → candidate browser dashboard channel
  for f in next.config.js nuxt.config.js vite.config.ts angular.json; do
    if [[ -f "$root/$f" ]]; then
      items=$(jq '. + [{name:"dashboard", driver:"browser", audience:"user",
             entry_point:"external", source:"web-ui-config", confidence:"low"}]' <<<"$items")
      break
    fi
  done

  echo "$items"
}
