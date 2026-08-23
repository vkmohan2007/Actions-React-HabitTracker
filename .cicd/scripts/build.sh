#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

TOOL=$(cfg "$CONFIG_FILE" ".build.tool" "")
CUSTOM_COMMAND=$(cfg "$CONFIG_FILE" ".build.buildCommand" "")

echo "Build tool: $TOOL"

if [[ -n "$CUSTOM_COMMAND" ]]; then
    echo "Running custom build command:"
    echo "$CUSTOM_COMMAND"

    eval "$CUSTOM_COMMAND"
    exit 0
fi

case "$TOOL" in

    npm)
        npm run build
        ;;

    yarn)
        yarn build
        ;;

    pnpm)
        pnpm build
        ;;

    maven)
        mvn -B clean package -DskipTests
        ;;

    gradle)
        ./gradlew clean build -x test
        ;;

    dotnet)
        dotnet build --configuration Release
        ;;

    pip)
        echo "Python project does not require a separate build step."
        ;;

    poetry)
        poetry build
        ;;

    composer)
        echo "PHP Composer project does not require a separate build step."
        ;;

    cargo)
        cargo build --release
        ;;

    *)
        echo "ERROR: Unsupported build tool: $TOOL"
        exit 1
        ;;
esac