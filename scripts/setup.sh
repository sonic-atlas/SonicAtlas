#!/bin/bash

set -e

# Colors :)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENV_EXAMPLE=".env.example"
MODE="dev"

while [[ $# -gt 0 ]]; do
    case $1 in
        --prod|--production)
            MODE="prod"
            shift
            ;;
        --dev|--development)
            MODE="dev"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dev|--prod]"
            echo ""
            echo "Options:"
            echo "  --dev, --development    Setup for development (default)"
            echo "  --prod, --production    Setup for production"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$MODE" = "prod" ]; then
    COMPOSE_FILE="docker-compose.yml"
    echo "SonicAtlas Setup Script (Production Mode)"
else
    COMPOSE_FILE="docker-compose.dev.yml"
    echo "SonicAtlas Setup Script (Development Mode)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"


echo "=========================="
echo ""

cd "$PROJECT_ROOT"

# Check if docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}✗ $COMPOSE_FILE not found${NC}"
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Creating from $ENV_EXAMPLE...${NC}"
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" .env
        echo -e "${GREEN}Created .env file${NC}"
    else
        echo -e "${RED}No .env example file found${NC}"
        exit 1
    fi
    echo ""
    echo -e "${YELLOW}Please edit .env with your configuration before continuing.${NC}"
    if [ "$MODE" = "prod" ]; then
        echo -e "${RED}IMPORTANT: Change all default passwords and secrets for production!${NC}"
    fi
    echo "Press Enter when ready..."
    read
fi

# Load environment variables
source .env

echo "Step 1: Installing dependencies"
echo "--------------------------------"
npm i
echo -e "${GREEN}Dependencies installed${NC}"
echo ""


echo "Step 2: Checking if Docker is installed"
echo "-----------------------"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose is not available${NC}"
    exit 1
fi
echo -e "${GREEN}Docker is available${NC}"
echo ""

echo "Step 3: Starting database"
echo "-------------------------"
echo "Starting PostgreSQL..."
docker compose -f "$COMPOSE_FILE" up -d db --build
sleep 20
echo ""
echo -e "${GREEN}Started PostgreSQL${NC}"
echo ""

echo "Step 4: Database setup"
echo "----------------------"
cd packages/backend
npm run db:migrate
cd "$PROJECT_ROOT"
echo -e "${GREEN}Database migrations applied${NC}"
echo ""

echo "Step 5: Creating storage directories"
echo "------------------------------------"
mkdir -p storage/originals storage/metadata storage/cache
echo -e "${GREEN}Storage directories created${NC}"
echo ""

echo "Step 6: Starting transcoder service"
echo "------------------------------------"
docker compose -f "$COMPOSE_FILE" up -d transcoder --build
sleep 20

echo "Checking transcoder service..."
TRANSCODER_READY=false
TRANSCODER_URL_CHECK="http://localhost:8000"

for i in {1..15}; do
    if curl -s "${TRANSCODER_URL_CHECK}/health" &> /dev/null; then
        TRANSCODER_READY=true
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

if [ "$TRANSCODER_READY" = true ]; then
    echo -e "${GREEN}Transcoder service is running${NC}"
else
    echo -e "${YELLOW}Transcoder service may not be ready yet${NC}"
    echo "Check with curl -s http://localhost:8000/health or check logs."
fi
echo ""

echo "Step 8: Starting backend service"
echo "--------------------------------"
docker compose -f "$COMPOSE_FILE" up -d backend --build
sleep 10
echo -e "${GREEN}Backend service started${NC}"
echo ""

echo "Step 9: Starting web service"
echo "----------------------------"
docker compose -f "$COMPOSE_FILE" up -d web --build
sleep 10
echo -e "${GREEN}Web service started${NC}"
echo ""

echo "================================"
echo -e "${GREEN}Setup complete!${NC}"
echo "================================"
echo ""

if [ "$MODE" = "dev" ]; then
    echo "Development mode setup completed."
    echo ""
    echo "To start development:"
    echo -e "  ${BLUE}./scripts/dev.sh${NC}"
    echo ""
    echo "Or start individual services:"
    echo -e "  Backend:  ${BLUE}cd packages/backend && npm run dev${NC}"
    echo -e "  Web:      ${BLUE}cd packages/web && npm run dev${NC}"
    echo ""
    echo "Services already running:"
    echo "  • PostgreSQL: localhost:5432"
    echo "  • Transcoder: localhost:8000"
    echo ""
    echo "After starting dev servers, visit:"
    echo -e "  ${BLUE}http://localhost:5173/setup${NC}"
else
    echo "Production mode setup completed."
    echo ""
    echo "All services are now running:"
    echo "  • PostgreSQL: localhost:5432"
    echo "  • Backend:    localhost:3000"
    echo "  • Transcoder: localhost:8000"
    echo "  • Web:        localhost:5173"
    echo ""
    echo "Complete the initial setup:"
    echo -e "  ${BLUE}http://localhost:5173/setup${NC}"
    echo ""
    echo "View logs:"
    echo -e "  ${BLUE}docker compose -f $COMPOSE_FILE logs -f${NC}"
    echo ""
    echo "Stop all services:"
    echo -e "  ${BLUE}docker compose -f $COMPOSE_FILE down${NC}"
fi

echo ""
echo -e "${YELLOW}The setup wizard will only be accessible on first run.${NC}"
if [ "$MODE" = "prod" ]; then
    echo -e "${RED}Remember to change default admin password immediately!${NC}"
fi