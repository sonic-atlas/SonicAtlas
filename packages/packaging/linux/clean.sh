#!/bin/bash
set -e
# SonicAtlas - Clean Build Artifacts (Linux)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/helpers.sh"

print_header "SonicAtlas Clean"

# --- Paths ---

APP_DIR="$SCRIPT_DIR/../../app"
DIST_DIR="$SCRIPT_DIR/../dist"
BUILD_DIR="$SCRIPT_DIR/build"

clean_packaging() {
  log_step "Cleaning packaging artifacts ($BUILD_DIR & $DIST_DIR)..."
  rm -rf "$BUILD_DIR"
  if [ -d "$DIST_DIR" ]; then
    rm -rf "$DIST_DIR"/*
  fi
  log_success "Packaging build artifacts cleaned"
}

clean_all() {
  log_step "Cleaning all build artifacts..."
  log_step "Cleaning app build directory ($APP_DIR/build)..."
  rm -rf "$APP_DIR/build"
  clean_packaging
  echo ""
  log_success "All build artifacts cleaned!"
}

# --- Main ---

case "${1:-all}" in
packaging)
  clean_packaging
  ;;
all)
  clean_all
  ;;
-h | --help)
  echo "Usage: $0 [target]"
  echo ""
  echo "Targets:"
  echo "  packaging  Clean packaging build & dist directories"
  echo "  all        Clean everything (default)"
  echo ""
  exit 0
  ;;
*)
  log_error "Unknown target: $1"
  echo "Use --help for usage information"
  exit 1
  ;;
esac
