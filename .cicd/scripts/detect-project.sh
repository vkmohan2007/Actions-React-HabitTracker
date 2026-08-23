#!/usr/bin/env bash
# Auto-detects project.language / build.tool / project.framework / project.name
# / runtime.version from marker files at the repo root, and writes
# .cicd/.detected.yml. lib/common.sh's merged_config() layers this file
# UNDER config.yml (defaults.yml -> .detected.yml -> config.yml), so a
# detected value only ever fills a gap — an explicit config.yml value always
# wins, and an unrecognized field is simply omitted rather than written as
# empty (so it doesn't clobber a mappings/defaults.yml default).
#
# Runs once per job: lib/common.sh's ensure_detected() skips re-running this
# if .cicd/.detected.yml already exists, since every job starts from a fresh
# checkout anyway (the file is gitignored, never committed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ROOT="${1:-.}"
ensure_yq

language=""
tool=""
framework=""
projectType=""

if [[ -f "$ROOT/pom.xml" ]]; then
  language="java"; tool="maven"; framework="spring-boot"; projectType="backend"

elif [[ -f "$ROOT/build.gradle" || -f "$ROOT/build.gradle.kts" ]]; then
  language="java"; tool="gradle"; framework="spring-boot"; projectType="backend"

elif [[ -f "$ROOT/Cargo.toml" ]]; then
  language="rust"; tool="cargo"; framework="cargo"; projectType="backend"

elif compgen -G "$ROOT/*.csproj" > /dev/null 2>&1 || compgen -G "$ROOT/*.sln" > /dev/null 2>&1; then
  language="csharp"; tool="dotnet"; framework="aspnetcore"; projectType="backend"

elif [[ -f "$ROOT/composer.json" ]]; then
  language="php"; tool="composer"; framework="php"; projectType="backend"
  grep -qi '"laravel/framework"' "$ROOT/composer.json" 2>/dev/null && framework="laravel"

elif [[ -f "$ROOT/package.json" ]]; then
  tool="npm"
  [[ -f "$ROOT/pnpm-lock.yaml" ]] && tool="pnpm"
  [[ -f "$ROOT/yarn.lock" ]] && tool="yarn"

  language="javascript"
  [[ -f "$ROOT/tsconfig.json" ]] && language="typescript"
  projectType="backend"

  if grep -q '"@angular/core"' "$ROOT/package.json" 2>/dev/null; then
    framework="angular"; language="typescript"; projectType="frontend"
  elif grep -q '"next"' "$ROOT/package.json" 2>/dev/null; then
    framework="next"; projectType="frontend"
  elif grep -q '"react"' "$ROOT/package.json" 2>/dev/null; then
    framework="react"; projectType="frontend"
  elif grep -q '"vue"' "$ROOT/package.json" 2>/dev/null; then
    framework="vue"; projectType="frontend"
  else
    framework="node"
  fi

elif [[ -f "$ROOT/pyproject.toml" ]]; then
  language="python"; framework="python"; projectType="backend"
  tool="pip"
  grep -q '\[tool.poetry\]' "$ROOT/pyproject.toml" 2>/dev/null && tool="poetry"

elif [[ -f "$ROOT/requirements.txt" || -f "$ROOT/Pipfile" ]]; then
  language="python"; tool="pip"; framework="python"; projectType="backend"
fi

version=""
if [[ -n "$language" ]]; then
  version=$(yq -r ".\"$language\".supportedVersions[-1] // \"\"" "$MAPPINGS_DIR/runtimes.yml" 2>/dev/null || true)
fi

name="${GITHUB_REPOSITORY:-}"
name="${name##*/}"
[[ -z "$name" ]] && name="$(basename "$(cd "$ROOT" && pwd)")"

{
  echo "project:"
  echo "  name: \"$name\""
  [[ -n "$language" ]]    && echo "  language: \"$language\""
  [[ -n "$framework" ]]   && echo "  framework: \"$framework\""
  [[ -n "$projectType" ]] && echo "  projectType: \"$projectType\""
  if [[ -n "$tool" ]]; then
    echo "build:"
    echo "  tool: \"$tool\""
  fi
  if [[ -n "$version" ]]; then
    echo "runtime:"
    echo "  version: \"$version\""
  fi
} > "$DETECTED_FILE"

if [[ -n "$language" ]]; then
  echo "Detected from project structure: name=$name language=$language tool=$tool framework=$framework runtimeVersion=${version:-<none>}"
else
  echo "Detected from project structure: name=$name (no recognized marker file found at repo root)"
  echo "Looked for: pom.xml, build.gradle*, Cargo.toml, *.csproj/*.sln, composer.json,"
  echo "package.json, pyproject.toml, requirements.txt/Pipfile."
  echo "Set project.language / build.tool explicitly in config.yml, or add a marker file."
fi
