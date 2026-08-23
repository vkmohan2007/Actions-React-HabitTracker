#!/usr/bin/env bash
# The actual toolchain install happens via the matching actions/setup-*
# step in the workflow (gated on `needs.validate.outputs.language`) because
# those actions provide caching and PATH wiring a plain script can't.
# This script just confirms the expected runtime landed on PATH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

LANGUAGE=$(cfg "$CONFIG_FILE" ".project.language" "")
VERSION=$(cfg "$CONFIG_FILE" ".runtime.version" "")
FAMILY=$(yq -r ".\"$LANGUAGE\".setup // \"\"" "$MAPPINGS_DIR/runtimes.yml")

echo "Language:             $LANGUAGE"
echo "Requested version:    $VERSION"
echo "Runtime family:       $FAMILY"
echo ""

case "$FAMILY" in
  node)   node --version; npm --version ;;
  java)   java -version ;;
  dotnet) dotnet --version ;;
  python) python --version ;;
  php)    php --version ;;
  rust)   rustc --version; cargo --version ;;
  *)
    echo "ERROR: No runtime setup defined for language '$LANGUAGE' (family '$FAMILY')."
    echo "Add a setup-* step for it in .github/workflows/ci-cd.yaml and an entry in"
    echo ".cicd/mappings/runtimes.yml."
    exit 1
    ;;
esac
