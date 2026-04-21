#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.paseo/config.json"

printf '\n[1/4] Check CodeBuddy binary\n'
if ! command -v codebuddy >/dev/null 2>&1; then
  printf '%s\n' 'codebuddy command not found in PATH.' >&2
  exit 1
fi
codebuddy --version >/dev/null
printf '%s\n' 'OK: codebuddy is available.'

printf '\n[2/4] Check provider config\n'
if [ ! -f "$CONFIG_FILE" ]; then
  printf 'Missing config file: %s\n' "$CONFIG_FILE" >&2
  exit 1
fi
if ! grep -q '"codebuddy"' "$CONFIG_FILE"; then
  printf 'Config does not contain a codebuddy provider: %s\n' "$CONFIG_FILE" >&2
  exit 1
fi
if ! grep -q '"extends"[[:space:]]*:[[:space:]]*"acp"' "$CONFIG_FILE"; then
  printf 'Config does not declare codebuddy as an ACP provider.\n' >&2
  exit 1
fi
printf '%s\n' 'OK: config contains a codebuddy ACP provider.'

printf '\n[3/4] Check daemon status\n'
npm --prefix "$ROOT_DIR" run cli -- daemon status

printf '\n[4/4] Manual smoke checklist\n'
printf '%s\n' 'Desktop:'
printf '%s\n' '  - Open agent creation and confirm codebuddy is visible.'
printf '%s\n' '  - Create a codebuddy agent and send a message.'
printf '%s\n' 'Mobile:'
printf '%s\n' '  - Pair the phone if needed: npm run cli -- daemon pair --json'
printf '%s\n' '  - Confirm the opencode slot appears with CodeBuddy label.'
printf '%s\n' '  - Create an agent and confirm it can send a message.'
printf '%s\n' '  - Run: npm run cli -- inspect <agent-id> and confirm Provider: codebuddy'

printf '\nPASS: local smoke prerequisites look good.\n'
