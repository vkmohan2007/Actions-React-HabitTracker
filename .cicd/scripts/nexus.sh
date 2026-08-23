#!/usr/bin/env bash
# Publishes the packaged build artifact (.cicd/output/, produced by
# package.sh) to a Nexus repository. Only the "raw" hosted-repository format
# is implemented — a plain HTTP PUT per file, which works regardless of
# project language. Other formats (maven2/npm/pypi/nuget/composer) are
# documented in mappings/artifact-repository-formats.yml as extension points;
# see .cicd/README.md "Publishing to an artifact repository".
#
# Usage: nexus.sh publish <config_file>
# Requires NEXUS_USERNAME / NEXUS_PASSWORD in the environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

COMMAND="${1:-publish}"
CONFIG_FILE="${2:-.cicd/config.yml}"
ensure_yq
ensure_detected

ENABLED=$(cfg "$CONFIG_FILE" ".artifactRepository.enabled" "false")
if [[ "$ENABLED" != "true" ]]; then
  echo "artifactRepository.enabled is not 'true'; nothing to publish."
  exit 0
fi

if [[ "$COMMAND" != "publish" ]]; then
  echo "ERROR: Unknown nexus.sh command '$COMMAND' (expected: publish)"
  exit 1
fi

URL=$(cfg "$CONFIG_FILE" ".artifactRepository.url" "")
REPOSITORY=$(cfg "$CONFIG_FILE" ".artifactRepository.repository" "")
FORMAT=$(cfg "$CONFIG_FILE" ".artifactRepository.format" "raw")
PROJECT_NAME=$(cfg "$CONFIG_FILE" ".project.name" "app")
GROUP_PATH=$(cfg "$CONFIG_FILE" ".artifactRepository.groupPath" "")
[[ -z "$GROUP_PATH" ]] && GROUP_PATH="$PROJECT_NAME"
VERSION=$(cfg "$CONFIG_FILE" ".artifactRepository.version" "")
[[ -z "$VERSION" ]] && VERSION="${GITHUB_SHA:-latest}"
OUTPUT_DIR=".cicd/output"

if [[ -z "$URL" || -z "$REPOSITORY" ]]; then
  echo "ERROR: artifactRepository.enabled is true but url/repository is not set."
  exit 1
fi

if [[ "$FORMAT" != "raw" ]]; then
  echo "ERROR: nexus.sh currently implements the 'raw' repository format only."
  echo "'$FORMAT' is not implemented — see mappings/artifact-repository-formats.yml"
  echo "and .cicd/README.md for how to extend this script to support it."
  exit 1
fi

if [[ ! -d "$OUTPUT_DIR" ]] || [[ -z "$(find "$OUTPUT_DIR" -type f -print -quit 2>/dev/null)" ]]; then
  echo "No files found in $OUTPUT_DIR; nothing to publish."
  exit 0
fi

: "${NEXUS_USERNAME:?NEXUS_USERNAME is required when artifactRepository.enabled is true}"
: "${NEXUS_PASSWORD:?NEXUS_PASSWORD is required when artifactRepository.enabled is true}"

BASE_URL="${URL%/}/repository/$REPOSITORY/$GROUP_PATH/$VERSION"
echo "Publishing artifacts from $OUTPUT_DIR to $BASE_URL/"

while IFS= read -r -d '' file; do
  rel_path="${file#"$OUTPUT_DIR"/}"
  target="$BASE_URL/$rel_path"
  echo "  PUT $rel_path -> $target"
  curl -sSf -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" --upload-file "$file" "$target"
done < <(find "$OUTPUT_DIR" -type f -print0)

echo ""
echo "Publish complete."
