#!/bin/bash
set -e

# Load color variables
source "$(dirname "$0")/utils/colors.sh"

BUILD_FLAG=false
DB_FLAG=false
DEV_FLAG=false
DB_GUI_FLAG=false
RESET_DB_FLAG=false

# flags
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD_FLAG=true
            echo "Option --build was set. Forcing rebuild..."
            shift
            ;;
        --db)
            DB_FLAG=true
            shift
            ;;
        --dev)
            DEV_FLAG=true
            shift
            ;;
        --db-gui)
            DB_GUI_FLAG=true
            shift
            ;;
        --reset-db)
            RESET_DB_FLAG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--db] [--dev] [--reset-db] [--build]"
            echo ""
            echo "Options:"
            echo "  --db         Start only the database container"
            echo "  --dev        Start dev servers with npm (not Docker)"
            echo "  --db-gui     Start drizzle-studio for database"
            echo "  --reset-db   Reset and rebuild the database container (for breaking changes)"
            echo "  -b, --build  Build before running"
            echo "  -h, --help   Show this help message"
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

if $RESET_DB_FLAG; then
    echo -e "${YELLOW}Resetting database container...${NC}"
    docker compose -f docker-compose.dev.yml stop db
    docker compose -f docker-compose.dev.yml rm -f db
    docker volume rm sonicatlas_postgres-data-dev || true
    echo -e "${BLUE}Rebuilding database container...${NC}"
    docker compose -f docker-compose.dev.yml up -d --build db
    echo -e "${GREEN}Database container reset and rebuilt!${NC}"
    exit 0
fi

if $DB_FLAG; then
    echo -e "${BLUE}Starting only the database container...${NC}"
    docker compose -f docker-compose.dev.yml up db
    exit 0
fi

if $DEV_FLAG; then
    echo -e "${BLUE}Starting dev servers with npm (not Docker)...${NC}"
    npm run dev
    exit 0
fi

if $DB_GUI_FLAG; then
    echo -e "${BLUE}Starting drizzle-studio for database...${NC}"
    npm run db:studio -w @sonic-atlas/backend
    exit 0
fi

if $BUILD_FLAG; then
   docker compose -f docker-compose.dev.yml up --build
fi

echo "Sonic Atlas is running!"
echo "Web: http://localhost:5173"
echo "API: http://localhost:3000"
echo "Transcoder: http://localhost:8000"