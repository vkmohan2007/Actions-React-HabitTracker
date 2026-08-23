#!/usr/bin/env bash
# Resolves Docker build metadata (dockerfile, image tag) from config so the
# workflow's docker/build-push-action steps stay config-driven. The actual
# build/push/scan is done by official actions; this script only computes
# the values they need.
#
# Usage: docker.sh <command> <config_file>
#   meta   Resolve dockerfile path + image tag, expose as step outputs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

COMMAND="${1:-meta}"
CONFIG_FILE="${2:-.cicd/config.yml}"
ensure_yq
ensure_detected

DOCKERFILE=$(cfg "$CONFIG_FILE" ".docker.dockerfile" "Dockerfile")
IMAGE_NAME=$(cfg "$CONFIG_FILE" ".docker.imageName" "$(cfg "$CONFIG_FILE" ".project.name" "app")")
REGISTRY_KEY=$(cfg "$CONFIG_FILE" ".docker.registry" "ghcr")

case "$REGISTRY_KEY" in
  ghcr) REGISTRY_HOST="ghcr.io/${GITHUB_REPOSITORY_OWNER:-owner}" ;;
  *)    REGISTRY_HOST="$REGISTRY_KEY" ;;
esac

TAG="$REGISTRY_HOST/$IMAGE_NAME:${GITHUB_SHA:-latest}"

case "$COMMAND" in
  meta)
    echo "Dockerfile: $DOCKERFILE"
    echo "Image tag:  $TAG"
    gh_output "dockerfile" "$DOCKERFILE"
    gh_output "tag" "$TAG"
    gh_output "imageName" "$IMAGE_NAME"
    ;;
  *)
    echo "ERROR: Unknown docker.sh command '$COMMAND' (expected: meta)"
    exit 1
    ;;
esac
