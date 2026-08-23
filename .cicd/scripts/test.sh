#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONFIG_FILE="${1:-.cicd/config.yml}"
ensure_yq
ensure_detected

CUSTOM_COMMAND=$(cfg "$CONFIG_FILE" ".build.testCommand" "")
TOOL=$(cfg "$CONFIG_FILE" ".build.tool" "")

if [[ -n "$CUSTOM_COMMAND" ]]; then
    echo "Running configured test command:"
    echo "$CUSTOM_COMMAND"

    eval "$CUSTOM_COMMAND"
    exit 0
fi

case "$TOOL" in

    npm)
        npm test -- --runInBand
        ;;

    yarn)
        yarn test
        ;;

    pnpm)
        pnpm test
        ;;

    maven)
        mvn -B test
        ;;

    gradle)
        ./gradlew test
        ;;

    dotnet)
        dotnet test --configuration Release
        ;;

    pip)
        pytest
        ;;

    poetry)
        poetry run pytest
        ;;

    composer)
        php artisan test
        ;;

    cargo)
        cargo test
        ;;

    *)
        echo "No default test implementation for $TOOL"
        echo "Skipping tests."
        ;;
esac