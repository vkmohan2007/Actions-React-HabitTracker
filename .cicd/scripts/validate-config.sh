#!/usr/bin/env bash
# Validates a project's .cicd config, applies defaults, and (when run as a
# GitHub Actions step with an `id:`) exposes the resolved values as step
# outputs so later jobs can gate stages with `if:` instead of re-parsing YAML.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

echo "======================================"
echo "CI/CD Configuration Validation"
echo "======================================"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# ---- required fields ----
# project.name always resolves (detect-project.sh falls back to the repo/dir
# name), but project.language and build.tool have no safe default: they only
# get filled in when detect-project.sh recognizes a marker file. If neither
# config.yml nor detection can supply them, fail with an actionable message.
NAME=$(cfg "$CONFIG_FILE" ".project.name" "")
LANGUAGE=$(cfg "$CONFIG_FILE" ".project.language" "")
TOOL=$(cfg "$CONFIG_FILE" ".build.tool" "")
VERSION=$(cfg "$CONFIG_FILE" ".runtime.version" "")

missing=0
if [[ -z "$NAME" ]]; then
  echo "ERROR: Missing required configuration: .project.name"
  missing=1
fi
if [[ -z "$LANGUAGE" ]]; then
  echo "ERROR: project.language is not set and could not be auto-detected from the"
  echo "       project structure. Set it explicitly in config.yml, or add a recognized"
  echo "       marker file to the repo root (see .cicd/scripts/detect-project.sh)."
  missing=1
fi
if [[ -z "$TOOL" ]]; then
  echo "ERROR: build.tool is not set and could not be auto-detected. Set it explicitly"
  echo "       in config.yml, or add a recognized marker file to the repo root."
  missing=1
fi
[[ $missing -eq 0 ]] || exit 1

DEPLOY_ENABLED=$(cfg "$CONFIG_FILE" ".deployment.enabled" "false")
DEPLOY_TYPE=$(cfg "$CONFIG_FILE" ".deployment.type" "container")
DEPLOY_TARGET=$(cfg "$CONFIG_FILE" ".deployment.target" "vps")

# ---- enum validation against the mapping files ----
if ! yq -e ".\"$LANGUAGE\"" "$MAPPINGS_DIR/runtimes.yml" >/dev/null 2>&1; then
  echo "ERROR: Unsupported project.language '$LANGUAGE'."
  echo "See .cicd/mappings/runtimes.yml for supported values, or add one there."
  exit 1
fi

if ! yq -e ".\"$TOOL\"" "$MAPPINGS_DIR/package-managers.yml" >/dev/null 2>&1; then
  echo "ERROR: Unsupported build.tool '$TOOL'."
  echo "See .cicd/mappings/package-managers.yml for supported values, or add one there."
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION=$(yq -r ".\"$LANGUAGE\".supportedVersions[-1] // \"\"" "$MAPPINGS_DIR/runtimes.yml")
  if [[ -z "$VERSION" ]]; then
    echo "ERROR: runtime.version is not set, was not auto-detected, and '$LANGUAGE' has no"
    echo "       documented supportedVersions to default to. Set runtime.version explicitly."
    exit 1
  fi
  echo "runtime.version not set; defaulting to '$VERSION' (newest documented for '$LANGUAGE')."
fi

supported_versions=$(yq -r ".\"$LANGUAGE\".supportedVersions[]" "$MAPPINGS_DIR/runtimes.yml" 2>/dev/null || true)
if [[ -n "$supported_versions" ]] && ! grep -qx "$VERSION" <<< "$supported_versions"; then
  echo "WARNING: runtime.version '$VERSION' is not in the documented supportedVersions for '$LANGUAGE'."
  echo "(.cicd/mappings/runtimes.yml). Continuing — this is a warning, not a failure."
fi

if [[ "$DEPLOY_ENABLED" == "true" ]]; then
  if ! yq -e ".\"$DEPLOY_TYPE\"" "$MAPPINGS_DIR/deployment-types.yml" >/dev/null 2>&1; then
    echo "ERROR: Unsupported deployment.type '$DEPLOY_TYPE'."
    echo "See .cicd/mappings/deployment-types.yml for supported values."
    exit 1
  fi
  if ! yq -e ".\"$DEPLOY_TYPE\".targets.\"$DEPLOY_TARGET\"" "$MAPPINGS_DIR/deployment-types.yml" >/dev/null 2>&1; then
    echo "ERROR: Unsupported deployment.target '$DEPLOY_TARGET' for deployment.type '$DEPLOY_TYPE'."
    echo "See .cicd/mappings/deployment-types.yml for supported values."
    exit 1
  fi
fi

ARTIFACT_REPO_ENABLED=$(cfg "$CONFIG_FILE" ".artifactRepository.enabled" "false")
ARTIFACT_REPO_FORMAT=$(cfg "$CONFIG_FILE" ".artifactRepository.format" "raw")

if [[ "$ARTIFACT_REPO_ENABLED" == "true" ]]; then
  if ! yq -e ".\"$ARTIFACT_REPO_FORMAT\"" "$MAPPINGS_DIR/artifact-repository-formats.yml" >/dev/null 2>&1; then
    echo "ERROR: Unsupported artifactRepository.format '$ARTIFACT_REPO_FORMAT'."
    echo "See .cicd/mappings/artifact-repository-formats.yml for supported values."
    exit 1
  fi
  if [[ -z "$(cfg "$CONFIG_FILE" ".artifactRepository.url" "")" ]]; then
    echo "ERROR: artifactRepository.enabled is true but artifactRepository.url is not set."
    exit 1
  fi
  if [[ -z "$(cfg "$CONFIG_FILE" ".artifactRepository.repository" "")" ]]; then
    echo "ERROR: artifactRepository.enabled is true but artifactRepository.repository is not set."
    exit 1
  fi
fi

echo ""
echo "Resolved configuration (config.yml merged over mappings/defaults.yml):"
merged_config "$CONFIG_FILE"
echo ""
echo "Configuration validation successful."

# ---- expose resolved values as job/step outputs ----
gh_output "language" "$LANGUAGE"
gh_output "tool" "$TOOL"
gh_output "runtimeVersion" "$VERSION"
gh_output "dockerEnabled" "$(cfg "$CONFIG_FILE" ".docker.enabled" "false")"
gh_output "sonarEnabled" "$(cfg "$CONFIG_FILE" ".quality.sonarEnabled" "false")"
gh_output "securityScanEnabled" "$(cfg "$CONFIG_FILE" ".security.securityScanEnabled" "true")"
gh_output "containerScan" "$(cfg "$CONFIG_FILE" ".security.containerScan" "true")"
gh_output "deploymentEnabled" "$DEPLOY_ENABLED"
gh_output "deploymentType" "$DEPLOY_TYPE"
gh_output "deploymentTarget" "$DEPLOY_TARGET"
gh_output "imageName" "$(cfg "$CONFIG_FILE" ".docker.imageName" "$(cfg "$CONFIG_FILE" ".project.name" "app")")"
gh_output "artifactRepositoryEnabled" "$ARTIFACT_REPO_ENABLED"
