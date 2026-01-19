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

# --- Clean Functions ---

clean_flutter() {
    log_step "Cleaning Flutter build artifacts..."
    if [ -d "$APP_DIR" ]; then
        cd "$APP_DIR"
        flutter clean
        cd "$SCRIPT_DIR"
        log_success "Flutter cleaned"
    else
        log_warning "App directory not found, skipping Flutter clean"
    fi
}

clean_dist() {
    log_step "Cleaning distribution directory..."
    if [ -d "$DIST_DIR" ]; then
        rm -rf "$DIST_DIR"/*
        log_success "Distribution directory cleaned"
    else
        log_warning "Distribution directory not found"
    fi
}

clean_build() {
    log_step "Cleaning build directory..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        log_success "Build directory cleaned"
    else
        log_warning "Build directory not found"
    fi
}

clean_all() {
    clean_flutter
    clean_build
    clean_dist
    echo ""
    log_success "All build artifacts cleaned!"
}

# --- Main ---

case "${1:-all}" in
    flutter)
        clean_flutter
        ;;
    dist)
        clean_dist
        ;;
    build)
        clean_build
        ;;
    all)
        clean_all
        ;;
    -h|--help)
        echo "Usage: $0 [target]"
        echo ""
        echo "Targets:"
        echo "  flutter    Clean Flutter build artifacts (flutter clean)"
        echo "  dist       Clean distribution directory"
        echo "  build      Clean Linux build directory (AppDir, etc.)"
        echo "  all        Clean everything (including Flutter) (default)"
        echo ""
        exit 0
        ;;
    *)
        log_error "Unknown target: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
