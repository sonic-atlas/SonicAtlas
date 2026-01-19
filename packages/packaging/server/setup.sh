#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/utils/colors.sh"

echo -e "${BLUE}INFO:${NC} Checking prerequisites..."

command -v docker &>/dev/null || {
  echo -e "${RED}ERROR:${NC} Docker is not installed. Please install Docker first."
  exit 1
}
command -v npm &>/dev/null || {
  echo -e "${RED}ERROR:${NC} npm is not installed. Please install Node.js and npm."
  exit 1
}
command -v pm2 &>/dev/null || {
  echo -e "${RED}ERROR:${NC} pm2 is not installed. Please install with 'npm install -g pm2'."
  exit 1
}
command -v ffmpeg &>/dev/null || {
  echo -e "${RED}ERROR:${NC} ffmpeg is not installed. This is required by the backend. Please install 'ffmpeg'."
  exit 1
}
echo -e "${GREEN}SUCCESS:${NC} All prerequisites found."

echo -e "${BLUE}INFO:${NC} Setting up production environment files..."

if [ -f ".env" ]; then
  set -a
  source ./.env
  set +a
fi

DEFAULT_DB_USER="${POSTGRES_USER:-sonic}"
DEFAULT_DB_NAME="${POSTGRES_DB:-sonic_db}"

echo -e "${BLUE}INFO:${NC} Configure database credentials used by Postgres container."
read -r -p "Postgres user [${DEFAULT_DB_USER}]: " INPUT_DB_USER
POSTGRES_USER=${INPUT_DB_USER:-$DEFAULT_DB_USER}

read -r -p "Postgres database name [${DEFAULT_DB_NAME}]: " INPUT_DB_NAME
POSTGRES_DB=${INPUT_DB_NAME:-$DEFAULT_DB_NAME}

read -s -r -p "Postgres password (leave blank to auto-generate): " INPUT_DB_PASS
echo
if [ -z "$INPUT_DB_PASS" ]; then
  if command -v openssl &>/dev/null; then
    POSTGRES_PASSWORD=$(openssl rand -base64 64)
  else
    POSTGRES_PASSWORD=$(head -c 18 /dev/urandom | base64)
  fi
  echo -e "${GREEN}Generated secure password:${NC} $POSTGRES_PASSWORD"
else
  POSTGRES_PASSWORD="$INPUT_DB_PASS"
fi


if command -v openssl &>/dev/null; then
  JWT_SECRET=$(openssl rand -base64 48)
else
  JWT_SECRET=$(head -c 36 /dev/urandom | base64)
fi
echo -e "${GREEN}Generated secure JWT secret:${NC} $JWT_SECRET"

read -s -r -p "Server password (leave blank to auto-generate): " INPUT_SERVER_PASS
echo
if [ -z "$INPUT_SERVER_PASS" ]; then
  if command -v openssl &>/dev/null; then
    SERVER_PASSWORD=$(openssl rand -base64 32)
  else
    SERVER_PASSWORD=$(head -c 24 /dev/urandom | base64)
  fi
  echo -e "${GREEN}Generated secure server password:${NC} $SERVER_PASSWORD"
else
  SERVER_PASSWORD="$INPUT_SERVER_PASS"
fi

if grep -q '^POSTGRES_USER=' .env 2>/dev/null; then
  sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=$POSTGRES_USER/" .env
else
  echo "POSTGRES_USER=$POSTGRES_USER" >> .env
fi
if grep -q '^POSTGRES_PASSWORD=' .env 2>/dev/null; then
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
else
  echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
fi
if grep -q '^POSTGRES_DB=' .env 2>/dev/null; then
  sed -i "s/^POSTGRES_DB=.*/POSTGRES_DB=$POSTGRES_DB/" .env
else
  echo "POSTGRES_DB=$POSTGRES_DB" >> .env
fi

DATABASE_URL="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/$POSTGRES_DB"
if grep -q '^DATABASE_URL=' .env 2>/dev/null; then
  sed -i "s|^DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" .env
else
  echo "DATABASE_URL=$DATABASE_URL" >> .env
fi


if grep -q '^JWT_SECRET=' .env 2>/dev/null; then
  sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
else
  echo "JWT_SECRET=$JWT_SECRET" >> .env
fi
if grep -q '^SERVER_PASSWORD=' .env 2>/dev/null; then
  sed -i "s/^SERVER_PASSWORD=.*/SERVER_PASSWORD=$SERVER_PASSWORD/" .env
else
  echo "SERVER_PASSWORD=$SERVER_PASSWORD" >> .env
fi

export POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
echo -e "${GREEN}SUCCESS:${NC} Database credentials saved to .env and exported."

if [ -f ".env.production.example" ]; then
  while IFS= read -r line; do
    if [[ "$line" =~ ^[A-Z0-9_]+= ]] && ! grep -q "^${line%%=*}=" .env; then
      echo "$line" >> .env
    fi
  done < .env.production.example
  echo -e "${GREEN}SUCCESS:${NC} Synced missing environment variables from .env.production.example to .env."
fi

if [ -f "packages/web/.env" ]; then
  echo -e "${YELLOW}WARN:${NC} 'packages/web/.env' already exists. Skipping creation."
else
  if [ -f "packages/web/.env.example" ]; then
    cp "packages/web/.env.example" "packages/web/.env"
  else
    touch "packages/web/.env"
  fi
  echo -e "${GREEN}SUCCESS:${NC} Ensured 'packages/web/.env' exists. ${YELLOW}Please edit this file with your production VITE_API_URL and VITE_WS_URL.${NC}"
fi

echo -e "${YELLOW}ACTION REQUIRED:${NC} Please review and ${RED}edit${NC} the .env files in 'packages/backend' and 'packages/web' before proceeding."
read -p "Press [Enter] to continue once .env files are configured..."


REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo -e "${BLUE}INFO:${NC} Installing all dependencies..."
npm install
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} npm install failed."
  exit 1
fi

echo -e "${BLUE}INFO:${NC} Starting Postgres database via Docker..."
docker compose -f docker-compose.yml up -d db
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} Docker Compose failed to start the database."
  exit 1
fi
echo -e "${GREEN}SUCCESS:${NC} Database container is running."

echo -e "${BLUE}INFO:${NC} Building..."
npm run build
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} Monorepo build failed."
  exit 1
fi
echo -e "${GREEN}SUCCESS:${NC} All projects built."

echo -e "${BLUE}INFO:${NC} Starting services with pm2..."

pm2 start "npm run start -w packages/backend" --name "sonic-atlas-backend"
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} Failed to start backend with pm2."
  exit 1
fi

pm2 start "node packages/web/build/index.js" --name "sonic-atlas-web" --env PORT=5173
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR:${NC} Failed to start web app with pm2."
  exit 1
fi

echo -e "${GREEN}SUCCESS:${NC} All services are running!"
pm2 list
echo -e "\n${BLUE}INFO:${NC} Your setup is complete. Services will restart automatically on server reboot."
echo -e "  - ${CYAN}Backend${NC} is running on port ${YELLOW}3000${NC}"
echo -e "  - ${CYAN}Web${NC} is running on port ${YELLOW}5173${NC}"
echo -e "Configure your reverse proxy to point to these ports."