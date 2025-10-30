#!/bin/bash
set -e

BUILD_FLAG=false

PARSED_OPTIONS=$(getopt -o "" -l "build" -n "$0" -- "$@")

if [ $? != 0]; then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$PARSED_OPTIONS"

while true; do
    case "$1" in
        --build)
            BUILD_FLAG = true
            echo "Option --build was set. Forcing rebuild..."
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error: unexpected options '$1'" >&2
            exit 1
            ;;
    esac
done

echo "Starting Sonic Atlas in development mode..."

if [ ! -f .env ]; then
    echo ".env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "Created .env - please edit it with your settings"
    exit 1
fi

mkdir -p storage/{originals,cache,metadata}

DOCKER_COMPOSE_COMMAND="docker compose -f docker-compose.dev.yml up"

if $BUILD_FLAG; then
    DOCKER_COMPOSE_COMMAND="docker compose -f docker-compose.dev.yml up --build"
fi

$DOCKER_COMPOSE_COMMAND

echo "Sonic Atlas is running!"
echo "Web: http://localhost:5173"
echo "API: http://localhost:3000"
echo "Transcoder: http://localhost:8000"