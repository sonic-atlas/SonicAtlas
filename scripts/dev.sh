#!/bin/bash
set -e

# Load color variables
source "$(dirname "$0")/utils/colors.sh"

BUILD_FLAG=false

# flags
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD_FLAG=true
            echo "Option --build was set. Forcing rebuild..."
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--build]"
            echo ""
            echo "Options:"
            echo "  -b, --build    Build before running"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Use --help for usage information"
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