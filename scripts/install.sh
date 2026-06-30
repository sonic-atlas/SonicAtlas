#!/bin/bash
set -e

# --- Helpers ---

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_input() {
  echo -e "${MAGENTA}!${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1"
}

log_step() {
  echo -e "${CYAN}→${NC} $1"
}

print_header() {
  local title="$1"
  local width=65
  echo ""
  echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
  printf "${CYAN}║${NC} ${BOLD}%-*s${NC}${CYAN}║${NC}\n" $((width - 1)) "$title"
  echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
  echo ""
}

print_section() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}$1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# --- Validation ---

if [ "$EUID" -ne 0 ]; then
  log_error "Please run this script as root or with sudo."
  exit 1
fi

OS_ID=$(. /etc/os-release && echo "$ID")
if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
  log_error "This script currently only supports Debian and Ubuntu."
  exit 1
fi

# --- Functions ---

check_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Required command '$1' not found."
    [ -n "$2" ] && echo -e "  ${DIM}$2${NC}"
    return 1
  fi
  return 0
}

ask_password() {
  while true; do
    log_input "Please enter the server password you wish to use: "
    read -r SERVER_PASSWORD </dev/tty
    echo ""
    
    log_input "Do you want to use $SERVER_PASSWORD? [y/n]: "
    read -r -n 1 CONTINUE </dev/tty
    echo ""

    if [[ "${CONTINUE,,}" == "y" ]]; then
      log_success "Using this password."
      break
    else
      echo ""
      log_warning "Password discarded."
    fi
  done
}

# --- Install ---

print_header "Sonic Atlas installation script"
print_section "Checking prerequisites"

if check_command docker "" >/dev/null && docker compose version >/dev/null 2>&1; then
  log_success "Docker already found."
else
  log_info "Docker missing or outdated."
  
  log_step "Updating package lists..."
  apt-get update -qq

  if [ "$OS_ID" = "ubuntu" ]; then
    DOCKER_PKGS="docker.io docker-compose-v2"
  else
    DOCKER_PKGS="docker.io docker-cli docker-compose"
  fi

  log_step "Installing Docker"
  apt-get install -y -qq $DOCKER_PKGS

  log_success "Docker installed successfully."
fi

print_section "Checking for Existing Setup"

log_step "Ensuring Docker service is enabled and running..."
if ! systemctl is-active --quiet docker; then
  systemctl enable --now docker >/dev/null 2>&1
  log_success "Docker service started."
fi

CONFLICTS_FOUND=0

log_step "Checking for conflicts"
if docker volume inspect sonic-atlas-db >/dev/null 2>&1; then
  log_warning "Found existing Docker volume 'sonic-atlas-db'."
  CONFLICTS_FOUND=1
fi

if [ -f ".env" ]; then
  log_warning "Found existing '.env' file."
  CONFLICTS_FOUND=1
fi

if [ -f "docker-compose.yml" ]; then
  log_warning "Found existing 'docker-compose.yml' file."
  CONFLICTS_FOUND=1
fi

if [ "$CONFLICTS_FOUND" -ne 0 ]; then
  echo ""
  log_error "Existing installation detected! Aborting to prevent data loss."
  echo -e "  ${DIM}To proceed, you must back up or remove the conflicting resources.${NC}"
  echo ""
  exit 1
fi

log_success "No existing setup found. Proceeding."

ask_password

print_section "Release Channel"

log_info "Choose a release channel:"
echo -e "  ${BOLD}1)${NC} ${GREEN}stable${NC} — Stable versions for fully tested releases and bug fixes"
echo -e "  ${BOLD}2)${NC} ${MAGENTA}edge${NC}   — Less tested on all platforms but relatively stable most of the time"
echo ""

while true; do
  log_input "Enter 1 or 2: "
  read -r CHANNEL_CHOICE </dev/tty
  case "$CHANNEL_CHOICE" in
    1) 
      RELEASE_CHANNEL="stable"
      log_step "Fetching latest stable release tag..."
      LATEST_TAG=$(curl -s https://api.github.com/repos/sonic-atlas/SonicAtlas/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
      if [ -z "$LATEST_TAG" ]; then
        log_warning "Could not fetch latest release tag, defaulting to 'latest'"
        IMAGE_TAG="latest"
      else
        IMAGE_TAG="$LATEST_TAG"
      fi
      break 
      ;;
    2) 
      RELEASE_CHANNEL="edge"
      IMAGE_TAG="edge"
      break 
      ;;
    *) log_warning "Invalid choice. Please enter 1 or 2." ;;
  esac
done

log_success "Using ${BOLD}${RELEASE_CHANNEL}${NC} channel (tag: ${IMAGE_TAG})."

print_section "Public Access Configuration"

log_info "How will you access this server?"
echo -e "  ${BOLD}1)${NC} ${GREEN}Public IP${NC}   — Direct access via IP address"
echo -e "  ${BOLD}2)${NC} ${YELLOW}Domain Name${NC} — Using a custom domain (e.g., sonic.example.com) + Nginx reverse proxy"
echo ""

while true; do
  log_input "Enter 1 or 2: "
  read -r ACCESS_CHOICE </dev/tty
  case "$ACCESS_CHOICE" in
    1) 
      ACCESS_MODE="ip"
      log_step "Detecting public IPv4 address..."
      DETECTED_IP=$(curl -4 -s ifconfig.me || echo "127.0.0.1")
      log_input "Detected IP: ${DETECTED_IP}. Press Enter to confirm, or type your IP/Hostname: "
      read -r USER_IP </dev/tty
      PUBLIC_ADDRESS="${USER_IP:-$DETECTED_IP}"
      
      PUBLIC_API_URL="http://${PUBLIC_ADDRESS}:3000"
      CORS_ORIGIN="http://${PUBLIC_ADDRESS}:3001"
      break 
      ;;
    2) 
      ACCESS_MODE="domain"
      while true; do
        log_input "Enter your domain name (e.g., sonic.example.com): "
        read -r USER_DOMAIN </dev/tty
        if [ -n "$USER_DOMAIN" ]; then
          PUBLIC_ADDRESS="$USER_DOMAIN"
          PUBLIC_API_URL="https://${PUBLIC_ADDRESS}/api"
          CORS_ORIGIN="https://${PUBLIC_ADDRESS}"
          break
        else
          log_warning "Domain cannot be empty."
        fi
      done
      break 
      ;;
    *) log_warning "Invalid choice. Please enter 1 or 2." ;;
  esac
done

log_success "Public address set to: ${BOLD}${PUBLIC_ADDRESS}${NC}"

print_section "Generating Credentials"

POSTGRES_PASSWORD="$(openssl rand -hex 24)"
JWT_SECRET="$(openssl rand -base64 32)"
WATCHTOWER_TOKEN="$(openssl rand -base64 32)"

log_success "Credentials generated."

print_section "Writing .env"

cat >".env" <<ENV_EOF
SERVER_PASSWORD=${SERVER_PASSWORD}

POSTGRES_USER=sonic
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=sonic_db

DATABASE_URL=postgresql://sonic:${POSTGRES_PASSWORD}@db:5432/sonic_db

NODE_ENV=production
BACKEND_PORT=3000

FFMPEG_PATH=/usr/bin/ffmpeg
STORAGE_PATH=storage
CORS_ORIGIN=${CORS_ORIGIN}
RATE_LIMIT_PER_MINUTE=1000
USER_RATE_LIMIT_PER_HOUR=1000
MUSICBRAINZ_DELAY=1000
PUBLIC_API_URL=${PUBLIC_API_URL}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=7d
MAX_CONCURRENT_TRANSCODES=4
DEBUG=false
TRUST_PROXY=1

RELEASE_CHANNEL=${RELEASE_CHANNEL}
WATCHTOWER_HTTP_API_TOKEN=${WATCHTOWER_TOKEN}
ENV_EOF

chmod 600 .env
log_success ".env written."

print_section "Writing docker-compose.yml"

if [ "$RELEASE_CHANNEL" = "edge" ]; then
  WATCHTOWER_ENVIRONMENT=$(cat <<'WTEOF'
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=300
      - WATCHTOWER_LABEL_ENABLE=true
WTEOF
)
else
  WATCHTOWER_ENVIRONMENT=$(cat <<WTEOF
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_LABEL_ENABLE=true
      - WATCHTOWER_HTTP_API_UPDATE=true
      - WATCHTOWER_HTTP_API_TOKEN=${WATCHTOWER_TOKEN}
      - WATCHTOWER_HTTP_API_PERIODIC_POLLS=false
WTEOF
)
fi

NGINX_SERVICE=""
if [ "$ACCESS_MODE" = "domain" ]; then
  NGINX_SERVICE=$(cat <<'NGINX_EOF'
  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
      - web
NGINX_EOF
)
fi

cat >"docker-compose.yml" <<COMPOSE_EOF
services:
  db:
    image: postgres:18-bookworm
    restart: unless-stopped
    env_file: .env
    volumes:
      - sonic-atlas-db:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    image: ghcr.io/sonic-atlas/sonicatlas-backend:${IMAGE_TAG}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    env_file: .env
    ports:
      - "3000:3000"
    volumes:
      - sonic-atlas-storage:/app/storage
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  web:
    image: ghcr.io/sonic-atlas/sonicatlas-web:${IMAGE_TAG}
    restart: unless-stopped
    depends_on:
      - backend
    env_file: .env
    environment:
      - PORT=3001
      - ORIGIN=${CORS_ORIGIN}
    ports:
      - "3001:3001"
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  watchtower:
    image: containrrr/watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
${WATCHTOWER_ENVIRONMENT}
$( [ "$RELEASE_CHANNEL" = "stable" ] && echo '    ports:
      - "127.0.0.1:8080:8080"' )

${NGINX_SERVICE}

volumes:
  sonic-atlas-db:
  sonic-atlas-storage:
COMPOSE_EOF

log_success "docker-compose.yml written."

if [ "$ACCESS_MODE" = "domain" ]; then
  log_step "Writing nginx.conf for domain reverse proxy..."
  
  cat >"nginx.conf" <<NGINX_CONF_EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name ${PUBLIC_ADDRESS};

    location /api {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        client_max_body_size 500M;
    }

    location /ws {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
    }

    location /health {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }

    location / {
        proxy_pass http://web:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX_CONF_EOF
  
  log_success "nginx.conf written."
fi

print_section "Starting Services"

log_step "Pulling images and starting containers..."
docker compose up -d

log_success "All containers started."

print_header "Installation Complete!"

if [ "$ACCESS_MODE" = "domain" ]; then
  echo -e "  ${GREEN}●${NC} Web UI:    ${BOLD}${CORS_ORIGIN}${NC}"
  echo -e "  ${GREEN}●${NC} Backend:   ${BOLD}${PUBLIC_API_URL}/health${NC}"
else
  echo -e "  ${GREEN}●${NC} Web UI:    ${BOLD}http://${PUBLIC_ADDRESS}:3001${NC}"
  echo -e "  ${GREEN}●${NC} Backend:   ${BOLD}http://${PUBLIC_ADDRESS}:3000${NC}"
fi

echo -e "  ${GREEN}●${NC} Channel:   ${BOLD}${RELEASE_CHANNEL} (${IMAGE_TAG})${NC}"

echo ""
if [ "$RELEASE_CHANNEL" = "stable" ]; then
  echo -e "  ${DIM}Updates: Use the web UI update banner when a new version is available.${NC}"
else
  echo -e "  ${DIM}Updates: Updates are done automatically on new commit${NC}"
fi
echo ""
