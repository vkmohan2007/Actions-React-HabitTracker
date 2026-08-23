#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

TOOL=$(cfg "$CONFIG_FILE" ".build.tool" "")
CUSTOM_COMMAND=$(cfg "$CONFIG_FILE" ".build.installCommand" "")

if [[ -n "$CUSTOM_COMMAND" ]]; then
  echo "Running configured install command:"
  echo "$CUSTOM_COMMAND"
  eval "$CUSTOM_COMMAND"
  exit 0
fi

DEFAULT_COMMAND=$(yq -r ".\"$TOOL\".install // \"\"" "$MAPPINGS_DIR/package-managers.yml")

if [[ -z "$DEFAULT_COMMAND" ]]; then
  echo "No install step required for build tool '$TOOL'."
  exit 0
fi

echo "Running default install command for '$TOOL':"
echo "$DEFAULT_COMMAND"
eval "$DEFAULT_COMMAND"
