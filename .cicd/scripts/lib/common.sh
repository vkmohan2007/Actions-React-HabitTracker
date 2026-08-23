#!/usr/bin/env bash
# Shared helpers sourced by every .cicd/scripts/*.sh script.
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CICD_DIR="$(cd "$LIB_DIR/../.." && pwd)"
MAPPINGS_DIR="$CICD_DIR/mappings"
DEFAULTS_FILE="$MAPPINGS_DIR/defaults.yml"
DETECTED_FILE="$CICD_DIR/.detected.yml"
DETECT_SCRIPT="$CICD_DIR/scripts/detect-project.sh"

# Installs yq (mikefarah/yq, Go implementation) if it isn't already on PATH.
# GitHub-hosted ubuntu-latest runners ship it, but this keeps scripts portable
# to self-hosted runners / local use.
ensure_yq() {
  if command -v yq >/dev/null 2>&1; then
    return 0
  fi

  echo "yq not found on PATH, installing..."
  local dest="/usr/local/bin/yq"
  local url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"

  if [[ -w "$(dirname "$dest")" ]]; then
    curl -sSL "$url" -o "$dest" && chmod +x "$dest"
  else
    sudo curl -sSL "$url" -o "$dest" && sudo chmod +x "$dest"
  fi
}

# ensure_detected
# Runs detect-project.sh (marker-file based: pom.xml -> java, package.json ->
# node/react/angular, Cargo.toml -> rust, requirements.txt -> python, etc.) if
# .cicd/.detected.yml doesn't already exist for this checkout. Idempotent
# within a job; every job re-detects since it starts from a fresh checkout.
ensure_detected() {
  if [[ ! -f "$DETECTED_FILE" ]]; then
    bash "$DETECT_SCRIPT"
  fi
}

# merged_config <config_file>
# Prints the project config merged on top of mappings/defaults.yml, with
# .cicd/.detected.yml (structure-based guesses) layered in between when it
# exists. Precedence, lowest to highest: defaults.yml -> .detected.yml ->
# <config_file>. A project's own config.yml value always wins.
merged_config() {
  local config_file="$1"
  if [[ -f "$DETECTED_FILE" ]]; then
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1) * select(fileIndex==2) | ... comments=""' \
      "$DEFAULTS_FILE" "$DETECTED_FILE" "$config_file"
  else
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1) | ... comments=""' "$DEFAULTS_FILE" "$config_file"
  fi
}

# cfg <config_file> <yq_path> [fallback]
# Reads one value out of the merged (defaults + project) config.
# Prints <fallback> (default: empty string) when the value is unset or null.
cfg() {
  local config_file="$1" path="$2" fallback="${3:-}"
  local value
  value=$(merged_config "$config_file" | yq -r "${path} // \"\"" -)
  if [[ -z "$value" || "$value" == "null" ]]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$value"
  fi
}

# gh_output <key> <value>
# Appends key=value to $GITHUB_OUTPUT when running inside a GitHub Actions step
# (id: set on the step); a no-op outside of Actions so scripts stay runnable locally.
gh_output() {
  local key="$1" value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${key}=${value}" >> "$GITHUB_OUTPUT"
  fi
}
