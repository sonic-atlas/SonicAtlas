#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/../common/helpers.sh"
source ./load_config.sh

# --- Menu ---

print_build_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${BOLD}SonicAtlas Build${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        Version: ${GREEN}$VERSION${NC}                                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_menu() {
    echo -e "${BOLD}Select build target:${NC}"
    echo ""
    echo -e "  ${BLUE}1)${NC} Build Tarball           ${YELLOW}(Generic Linux)${NC}"
    echo -e "  ${BLUE}2)${NC} Build AppImage          ${YELLOW}(+ Tarball)${NC}"
    echo -e "  ${BLUE}3)${NC} Build Android APKs      ${YELLOW}(Split per ABI)${NC}"
    echo -e "  ${BLUE}4)${NC} Build All"
    echo ""
    echo -e "  ${BLUE}5)${NC} Clean                   ${YELLOW}(Remove build artifacts)${NC}"
    echo -e "  ${BLUE}0)${NC} Exit"
    echo ""
}

# --- Flutter Builders ---

build_flutter_linux() {
    log_step "Building Flutter Linux release..."
    cd "$APP_DIR"
    flutter build linux --release
    cd "$SCRIPT_DIR"
    
    log_success "Flutter Linux build complete"
}

build_flutter_android() {
    log_step "Building Flutter Android release (split-per-abi)..."
    cd "$APP_DIR"
    flutter build apk --release --split-per-abi
    cd "$SCRIPT_DIR"
    log_success "Flutter Android build complete"
}

# --- Build Targets ---

do_build_tarball() {
    print_section "Building Tarball..."
    
    build_flutter_linux
    ./tarball.sh
    
    log_success "Tarball built successfully!"
    echo -e "  Output: ${BLUE}$RELEASE_DIR/${APP_NAME}-${VERSION}-x64-Linux.tar.gz${NC}"
}

do_build_appimage() {
    print_section "Building AppImage..."
    
    do_build_tarball
    
    print_section "Packaging AppImage..."
    ./appimage.sh
    
    log_success "AppImage built successfully!"
    echo -e "  Output: ${BLUE}$RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage${NC}"
}

do_build_android() {
    print_section "Building Android APKs..."
    
    check_command "flutter" "Install from: https://flutter.dev" || return 1
    
    ./android.sh
    
    log_success "Android APKs built successfully!"
    echo -e "  Output: ${BLUE}$RELEASE_DIR/${NC}"
}

do_build_all() {
    print_section "Building All Targets..."
    
    build_flutter_linux

    print_section "Packaging Tarball..."
    ./tarball.sh
    echo -e "  Output: ${BLUE}$RELEASE_DIR/${APP_NAME}-${VERSION}-Linux.tar.gz${NC}"

    print_section "Packaging AppImage..."
    ./appimage.sh
    echo -e "  Output: ${BLUE}$RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage${NC}"
    
    do_build_android
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    log_success "All builds completed successfully!"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
}

# --- Main ---

main() {
    print_build_header
    
    check_command "yq" "Install with: sudo pacman -S yq" || exit 1
    check_command "flutter" "Install from: https://flutter.dev" || exit 1
    
    while true; do
        print_menu
        read -rp "Enter choice [0-5]: " choice
        
        case $choice in
            1)
                do_build_tarball
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            2)
                do_build_appimage
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            3)
                do_build_android
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            4)
                do_build_all
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            5)
                ./clean.sh
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            0)
                echo "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                ;;
        esac
    done
}

main "$@"
