#!/bin/bash
set -e

# Load color variables
source "$(dirname "$0")/utils/colors.sh"

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

# Configuration function
configure_environment() {
    echo ""
    echo -e "${BLUE}Configuration Setup${NC}"
    echo "===================="
    echo ""
    
    if [ "$MODE" = "prod" ]; then
        echo -e "${YELLOW}Production mode - Please provide secure credentials${NC}"
    else
        echo -e "${YELLOW}Development mode - You can use defaults or customize${NC}"
    fi
    echo ""
    
    # Database/User name
    read -p "Database and username [sonic]: " DB_NAME
    DB_NAME="${DB_NAME:-sonic}"
    
    # Database password
    if [ "$MODE" = "prod" ]; then
        read -sp "Database password (required): " DB_PASSWORD
        echo ""
        if [ -z "$DB_PASSWORD" ]; then
            echo -e "${RED}Database password is required for production${NC}"
            exit 1
        fi
    else
        read -sp "Database password [devpassword]: " DB_PASSWORD
        echo ""
        DB_PASSWORD="${DB_PASSWORD:-devpassword}"
    fi
    
    # Server/API password
    if [ "$MODE" = "prod" ]; then
        read -sp "Server API password (required): " API_PASSWORD
        echo ""
        if [ -z "$API_PASSWORD" ]; then
            echo -e "${RED}Server password is required for production${NC}"
            exit 1
        fi
    else
        read -sp "Server API password [devpassword123]: " API_PASSWORD
        echo ""
        API_PASSWORD="${API_PASSWORD:-devpassword123}"
    fi
    
    # CORS Origin for production
    if [ "$MODE" = "prod" ]; then
        read -p "CORS Origin (your domain, e.g., https://yourdomain.com): " CORS_ORIGIN_INPUT
        CORS_ORIGIN_INPUT="${CORS_ORIGIN_INPUT:-http://localhost:5173}"
    else
        CORS_ORIGIN_INPUT="http://localhost:5173"
    fi
    
    echo ""
    echo -e "${GREEN}Configuration summary:${NC}"
    echo "  Database/User: $DB_NAME"
    echo "  Database password: $(echo $DB_PASSWORD | sed 's/./*/g')"
    echo "  Server password: $(echo $API_PASSWORD | sed 's/./*/g')"
    if [ "$MODE" = "prod" ]; then
        echo "  CORS Origin: $CORS_ORIGIN_INPUT"
    fi
    echo ""
    
    read -p "Continue with this configuration? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Export variables
    export POSTGRES_USER="$DB_NAME"
    export POSTGRES_PASSWORD="$DB_PASSWORD"
    export POSTGRES_DB="${DB_NAME}_db"
    export SERVER_PASSWORD="$API_PASSWORD"
    export CORS_ORIGIN="$CORS_ORIGIN_INPUT"
}

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Creating new configuration...${NC}"
    
    # Get configuration from user
    configure_environment
    
    # Create .env file
    if [ "$MODE" = "prod" ]; then
        TEMPLATE_FILE=".env.production.example"
    else
        TEMPLATE_FILE="$ENV_EXAMPLE"
    fi
    
    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo -e "${RED}Template file $TEMPLATE_FILE not found${NC}"
        exit 1
    fi
    
    # Copy template and update values
    cp "$TEMPLATE_FILE" .env
    
    # Update the .env file with user values
    sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=$POSTGRES_USER/" .env
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
    sed -i "s/^POSTGRES_DB=.*/POSTGRES_DB=$POSTGRES_DB/" .env
    sed -i "s/^SERVER_PASSWORD=.*/SERVER_PASSWORD=$SERVER_PASSWORD/" .env
    sed -i "s|^CORS_ORIGIN=.*|CORS_ORIGIN=$CORS_ORIGIN|" .env
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/$POSTGRES_DB|" .env
    
    echo -e "${GREEN}Created .env file with your configuration${NC}"
    
    # Create web frontend .env file
    echo -e "${YELLOW}Creating web frontend configuration...${NC}"
    WEB_ENV_FILE="packages/web/.env"
    
    if [ "$MODE" = "prod" ]; then
        # For production, use the actual API URL
        echo "PUBLIC_API_URL=http://localhost:3000" > "$WEB_ENV_FILE"
    else
        # For development, use localhost
        echo "PUBLIC_API_URL=http://localhost:3000" > "$WEB_ENV_FILE"
    fi
    
    echo -e "${GREEN}Created web frontend .env file${NC}"
else
    echo -e "${GREEN}.env file already exists${NC}"
    
    # Load existing environment variables
    set -a
    source .env
    set +a
    
    # Set defaults for dev mode if not in .env
    if [ "$MODE" = "dev" ]; then
        export POSTGRES_USER="${POSTGRES_USER:-sonic}"
        export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-devpassword}"
        export POSTGRES_DB="${POSTGRES_DB:-sonic_db}"
        export SERVER_PASSWORD="${SERVER_PASSWORD:-devpassword123}"
        export CORS_ORIGIN="${CORS_ORIGIN:-http://localhost:5173}"
    fi
    
    # Update or create web .env if it doesn't exist
    WEB_ENV_FILE="packages/web/.env"
    if [ ! -f "$WEB_ENV_FILE" ]; then
        echo -e "${YELLOW}Updating web frontend configuration...${NC}"
        echo "PUBLIC_API_URL=http://localhost:3000" > "$WEB_ENV_FILE"
        echo -e "${GREEN}Updated web frontend .env file${NC}"
    fi
fi

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

echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; then
        echo -e "${GREEN}PostgreSQL is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
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

echo "Waiting for transcoder service..."
TRANSCODER_READY=false
TRANSCODER_URL_CHECK="http://localhost:8000"

for i in {1..30}; do
    if curl -s "${TRANSCODER_URL_CHECK}/health" &> /dev/null; then
        TRANSCODER_READY=true
        echo -e "${GREEN}Transcoder service is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

if [ "$TRANSCODER_READY" = false ]; then
    echo -e "${YELLOW}Transcoder service may not be ready yet${NC}"
    echo "Check with: curl http://localhost:8000/health"
fi
echo ""

echo "Step 8: Starting backend service"
echo "--------------------------------"
docker compose -f "$COMPOSE_FILE" up -d backend --build

echo "Waiting for backend service..."
for i in {1..30}; do
    if curl -s "http://localhost:3000/health" &> /dev/null; then
        echo -e "${GREEN}Backend service is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

echo "Step 9: Starting web service"
echo "----------------------------"
docker compose -f "$COMPOSE_FILE" up -d web --build

echo "Waiting for web service..."
for i in {1..30}; do
    if curl -s "http://localhost:5173" &> /dev/null; then
        echo -e "${GREEN}Web service is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
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