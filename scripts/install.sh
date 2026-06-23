#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

# --- Helpers ---

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m'

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
    read SERVER_PASSWORD
    echo ""
    
    log_input "Do you want to use $SERVER_PASSWORD? [y/n]: "
    read -n 1 CONTINUE
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

if check_command docker "" && docker compose version >/dev/null 2>&1; then
  log_success "Docker already found."
else
  log_info "Docker missing or outdated."
  
  log_step "Updating package lists..."
  apt-get update

  OS_ID=$(. /etc/os-release && echo "$ID")
  
  if [ "$OS_ID" = "ubuntu" ]; then
    COMPOSE_PKG="docker-compose-v2"
    DOCKER_PKG="docker.io"
  else
    COMPOSE_PKG="docker-compose"
    DOCKER_PKG="docker-cli"
  fi

  log_step "Installing Docker"
  apt-get install -y "$DOCKER_PKG" "$COMPOSE_PKG"

  log_success "Docker installed successfully."
fi

if check_command ffmpeg "" >/dev/null 2>&1; then
  log_success "ffmpeg already found."
else
  log_info "ffmpeg missing or outdated."

  log_step "Updating package lists..."
  apt-get update
   
  log_step "Installing ffmpeg"
  apt-get install -y ffmpeg
  
  log_success "ffmpeg installed successfully."
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

log_step "Creating .env"

POSTGRES_PASSWORD="$(openssl rand -base64 18)"
JWT_SECRET="$(openssl rand -base64 32)"

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
CORS_ORIGIN=http://localhost:5173
RATE_LIMIT_PER_MINUTE=1000
USER_RATE_LIMIT_PER_HOUR=1000
MUSICBRAINZ_DELAY=1000
PUBLIC_API_URL=http://localhost:3000
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=7d
MAX_CONCURRENT_TRANSCODES=4
DEBUG=false
TRUST_PROXY=1
ENV_EOF