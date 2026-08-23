#!/usr/bin/env bash
# Generates sonar-project.properties from config so the official
# SonarSource/sonarqube-scan-action (invoked by the workflow right after this
# script) picks up project-appropriate settings without any hardcoding in the
# main pipeline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

if [[ -f sonar-project.properties ]]; then
  echo "sonar-project.properties already exists at the repo root — using it as-is"
  echo "instead of generating one. Delete it if you want this script to regenerate"
  echo "a generic one from config.yml."
  cat sonar-project.properties
  exit 0
fi

PROJECT_NAME=$(cfg "$CONFIG_FILE" ".project.name" "app")
LANGUAGE=$(cfg "$CONFIG_FILE" ".project.language" "")
COVERAGE_PATH=$(cfg "$CONFIG_FILE" ".build.coveragePath" "")

{
  echo "sonar.projectKey=$PROJECT_NAME"
  echo "sonar.projectName=$PROJECT_NAME"
  echo "sonar.sources=."
  echo "sonar.sourceEncoding=UTF-8"
} > sonar-project.properties

case "$LANGUAGE" in
  javascript|typescript)
    echo "sonar.exclusions=node_modules/**,dist/**,build/**" >> sonar-project.properties
    [[ -n "$COVERAGE_PATH" ]] && echo "sonar.javascript.lcov.reportPaths=$COVERAGE_PATH/lcov.info" >> sonar-project.properties
    ;;
  java)
    [[ -n "$COVERAGE_PATH" ]] && echo "sonar.coverage.jacoco.xmlReportPaths=$COVERAGE_PATH/jacoco.xml" >> sonar-project.properties
    ;;
  csharp)
    [[ -n "$COVERAGE_PATH" ]] && echo "sonar.cs.opencover.reportsPaths=$COVERAGE_PATH/**/coverage.opencover.xml" >> sonar-project.properties
    ;;
  python)
    [[ -n "$COVERAGE_PATH" ]] && echo "sonar.python.coverage.reportPaths=$COVERAGE_PATH/coverage.xml" >> sonar-project.properties
    ;;
  php)
    [[ -n "$COVERAGE_PATH" ]] && echo "sonar.php.coverage.reportPaths=$COVERAGE_PATH/clover.xml" >> sonar-project.properties
    ;;
  *)
    echo "No language-specific Sonar properties defined for '$LANGUAGE'; using generic defaults."
    ;;
esac

echo "Generated sonar-project.properties:"
cat sonar-project.properties
