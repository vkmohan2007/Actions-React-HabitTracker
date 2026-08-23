#!/usr/bin/env bash
# Resolves which security scans are enabled for this project and exposes
# them as step outputs. The actual scanning is done by the official
# aquasecurity/trivy-action steps in the workflow (gated on these outputs)
# rather than a hand-rolled Trivy install here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

FS_SCAN=$(cfg "$CONFIG_FILE" ".security.filesystemScan" "true")
DEP_SCAN=$(cfg "$CONFIG_FILE" ".security.dependencyScan" "true")
CONTAINER_SCAN=$(cfg "$CONFIG_FILE" ".security.containerScan" "true")

echo "Filesystem scan enabled: $FS_SCAN"
echo "Dependency scan enabled: $DEP_SCAN"
echo "Container scan enabled:  $CONTAINER_SCAN"

gh_output "filesystemScan" "$FS_SCAN"
gh_output "dependencyScan" "$DEP_SCAN"
gh_output "containerScan" "$CONTAINER_SCAN"
