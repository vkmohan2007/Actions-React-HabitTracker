#!/usr/bin/env bash
# Resolves deployment settings (defaults -> config.yml -> environments/<env>.yml
# overlay, in that precedence order) and exposes them as step outputs for the
# workflow's deploy steps.
#
# Currently implements the "container" + "vps" combination end-to-end (SSH in,
# `docker run` the image) via appleboy/ssh-action in the workflow. Any other
# deployment.type/target documented in .cicd/mappings/deployment-types.yml
# resolves cleanly but fails loudly here until a deploy step for it is added —
# see .cicd/README.md "Adding a deployment target".
#
# Usage: deploy.sh resolve <config_file> <environment>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

COMMAND="${1:-resolve}"
CONFIG_FILE="${2:-.cicd/config.yml}"
ENVIRONMENT="${3:-dev}"
ensure_yq
ensure_detected

ENV_FILE="$CICD_DIR/environments/$ENVIRONMENT.yml"

# resolved <yq_path> <fallback>
# Like `cfg`, but also layers environments/<env>.yml on top (highest precedence).
resolved() {
  local path="$1" fallback="$2" value
  if [[ -f "$ENV_FILE" && -s "$ENV_FILE" ]]; then
    value=$(yq eval-all 'select(fileIndex==0) * select(fileIndex==1) * select(fileIndex==2)' \
      "$DEFAULTS_FILE" "$CONFIG_FILE" "$ENV_FILE" | yq -r "${path} // \"\"" -)
  else
    value=$(cfg "$CONFIG_FILE" "$path" "")
  fi
  if [[ -z "$value" || "$value" == "null" ]]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$value"
  fi
}

TYPE=$(resolved ".deployment.type" "container")
TARGET=$(resolved ".deployment.target" "vps")
IMAGE_NAME=$(resolved ".docker.imageName" "$(resolved ".project.name" "app")")
REGISTRY_KEY=$(resolved ".docker.registry" "ghcr")
PORT=$(resolved ".deployment.container.port" "8080")
HOST_PORT=$(resolved ".deployment.container.hostPort" "8080")
RESTART=$(resolved ".deployment.container.restartPolicy" "unless-stopped")

case "$REGISTRY_KEY" in
  ghcr) REGISTRY_HOST="ghcr.io/${GITHUB_REPOSITORY_OWNER:-owner}" ;;
  *)    REGISTRY_HOST="$REGISTRY_KEY" ;;
esac
IMAGE="$REGISTRY_HOST/$IMAGE_NAME:${GITHUB_SHA:-latest}"

case "$COMMAND" in
  resolve)
    echo "Environment:       $ENVIRONMENT"
    echo "Deployment type:   $TYPE"
    echo "Deployment target: $TARGET"
    echo "Image:             $IMAGE"
    echo "Port mapping:      $HOST_PORT:$PORT"
    echo "Restart policy:    $RESTART"

    if [[ "$TYPE" != "container" || "$TARGET" != "vps" ]]; then
      echo ""
      echo "ERROR: deploy.sh currently implements 'container' deployments to the 'vps'"
      echo "target only. '$TYPE/$TARGET' is documented in .cicd/mappings/deployment-types.yml"
      echo "but has no deploy step yet. Extend this script and add a matching workflow"
      echo "step to support it."
      exit 1
    fi

    gh_output "target" "$TARGET"
    gh_output "image" "$IMAGE"
    gh_output "containerName" "$IMAGE_NAME"
    gh_output "port" "$PORT"
    gh_output "hostPort" "$HOST_PORT"
    gh_output "restartPolicy" "$RESTART"
    ;;
  *)
    echo "ERROR: Unknown deploy.sh command '$COMMAND' (expected: resolve)"
    exit 1
    ;;
esac
