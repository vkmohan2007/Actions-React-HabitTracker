#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

LINT_COMMAND=$(cfg "$CONFIG_FILE" ".build.lintCommand" "")

if [[ -z "$LINT_COMMAND" ]]; then
  echo "No build.lintCommand configured for this project. Skipping lint."
  exit 0
fi

echo "Running configured lint command:"
echo "$LINT_COMMAND"
eval "$LINT_COMMAND"
