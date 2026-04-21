#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_FILE="$ROOT_DIR/packages/server/src/server/session.ts"
SNAPSHOT_FILE="$ROOT_DIR/packages/server/src/server/agent/provider-snapshot-manager.ts"
WEBSOCKET_FILE="$ROOT_DIR/packages/server/src/server/websocket-server.ts"
TEMPLATE_FILE="$ROOT_DIR/templates/codebuddy-provider.config.template.json"

check_marker() {
  local file="$1"
  local marker="$2"
  if ! grep -F -q "$marker" "$file"; then
    printf 'Missing marker: %s in %s\n' "$marker" "$file" >&2
    exit 1
  fi
}

printf '\n[1/5] Build server workspace\n'
npm --prefix "$ROOT_DIR" run build --workspace=@getpaseo/server

printf '\n[2/5] Run server typecheck\n'
npm --prefix "$ROOT_DIR" run typecheck --workspace=@getpaseo/server

printf '\n[3/5] Run format check\n'
npm --prefix "$ROOT_DIR" run format:check

printf '\n[4/5] Verify CodeBuddy compatibility markers\n'
check_marker "$SESSION_FILE" 'MOBILE_PROVIDER_ALIAS_SOURCE = "codebuddy"'
check_marker "$SESSION_FILE" 'MOBILE_PROVIDER_ALIAS_TARGET = "opencode"'
check_marker "$SESSION_FILE" 'shouldUseMobileProviderAlias'
check_marker "$SESSION_FILE" 'mapProviderForClient'
check_marker "$SESSION_FILE" 'mapProviderFromClient'
check_marker "$SESSION_FILE" 'mapModeIdFromClient'
check_marker "$SESSION_FILE" 'transformProviderSnapshotEntriesForClient'
check_marker "$SESSION_FILE" 'handleGetProvidersSnapshotRequest'
check_marker "$SNAPSHOT_FILE" 'async getSnapshotReady'
check_marker "$WEBSOCKET_FILE" 'clientType: WSHelloMessage["clientType"]'
check_marker "$WEBSOCKET_FILE" 'updateClientType(message.clientType)'
if [ ! -f "$TEMPLATE_FILE" ]; then
  printf 'Missing template file: %s\n' "$TEMPLATE_FILE" >&2
  exit 1
fi

printf '\n[5/5] Manual follow-up\n'
printf '%s\n' 'Now do the minimum GUI verification:'
printf '%s\n' '  1. Desktop: create a codebuddy agent and send a message.'
printf '%s\n' '  2. Mobile: create an opencode slot agent and confirm it works.'
printf '%s\n' '  3. Inspect the mobile-created agent and confirm Provider: codebuddy.'

printf '\nPASS: post-merge checks completed.\n'
