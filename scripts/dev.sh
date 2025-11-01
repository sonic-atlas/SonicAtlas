#!/bin/bash
set -e

# Load color variables
source "$(dirname "$0")/utils/colors.sh"

BUILD_FLAG=false
INSTALL_FLAG=false

# flags
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD_FLAG=true
            echo "Option --build was set. Forcing rebuild..."
            shift
            ;;
        -i|--install)
            INSTALL_FLAG=true
            echo "Option --install was set. Will install dependencies..."
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--build] [--install]"
            echo ""
            echo "Options:"
            echo "  -b, --build    Build before running"
            echo "  -i, --install  Install dependencies in containers"
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

if $INSTALL_FLAG; then
    echo -e "${BLUE}Installing dependencies in containers...${NC}"
    
    docker compose -f docker-compose.dev.yml up -d
    
    echo -e "${BLUE}Installing web dependencies...${NC}"
    docker compose -f docker-compose.dev.yml exec web npm install
    
    echo -e "${BLUE}Installing backend dependencies...${NC}"
    docker compose -f docker-compose.dev.yml exec backend sh -c "cd /app/packages/backend && npm install"
    
    echo -e "${GREEN}Dependencies installed successfully!${NC}"
    echo -e "${YELLOW}Restarting containers...${NC}"
    
    docker compose -f docker-compose.dev.yml restart web backend
    
    docker compose -f docker-compose.dev.yml logs -f
    
    exit 0
fi

DOCKER_COMPOSE_COMMAND="docker compose -f docker-compose.dev.yml up"

if $BUILD_FLAG; then
    DOCKER_COMPOSE_COMMAND="docker compose -f docker-compose.dev.yml up --build"
fi

$DOCKER_COMPOSE_COMMAND

echo "Sonic Atlas is running!"
echo "Web: http://localhost:5173"
echo "API: http://localhost:3000"
echo "Transcoder: http://localhost:8000"