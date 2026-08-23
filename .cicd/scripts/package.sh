#!/usr/bin/env bash
# Stages build.artifactPath (may be a glob, e.g. target/*.jar) into
# .cicd/output/, which the workflow then uploads as the build artifact.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

ARTIFACT_PATH=$(cfg "$CONFIG_FILE" ".build.artifactPath" "")
OUTPUT_DIR=".cicd/output"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ -z "$ARTIFACT_PATH" || "$ARTIFACT_PATH" == "." ]]; then
  echo "build.artifactPath is unset or '.' (whole working tree, e.g. PHP/Laravel"
  echo "deployed via 'COPY . .' in Dockerfile) — no separate artifact to stage."
  exit 0
fi

shopt -s nullglob
matches=($ARTIFACT_PATH)
shopt -u nullglob

if [[ ${#matches[@]} -eq 0 ]]; then
  echo "WARNING: build.artifactPath '$ARTIFACT_PATH' matched nothing. Skipping packaging."
  exit 0
fi

for m in "${matches[@]}"; do
  echo "Packaging: $m"
  cp -r "$m" "$OUTPUT_DIR/"
done

echo ""
echo "Artifact staged in $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"
