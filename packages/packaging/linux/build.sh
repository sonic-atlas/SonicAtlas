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
  echo -e "  ${BLUE}3)${NC} Build Android APK       ${YELLOW}(Signed single APK)${NC}"
  echo -e "  ${BLUE}4)${NC} Build All"
  echo ""
  echo -e "  ${BLUE}5)${NC} Clean Packaging         ${YELLOW}(Remove packaging/build & dist)${NC}"
  echo -e "  ${BLUE}6)${NC} Clean All               ${YELLOW}(Remove all build artifacts)${NC}"
  echo -e "  ${BLUE}0)${NC} Exit"
  echo ""
}

# --- Qt Builders ---

build_qt_linux() {
  log_step "Building Qt CMake Linux release..."
  cd "$APP_DIR"
  # TODO: Generate open source licenses
  cmake --preset gcc-release
  cmake --build --preset gcc-release
  cd "$SCRIPT_DIR"

  log_success "Qt Linux build complete"
}

# --- Build Targets ---

do_build_tarball() {
  print_section "Building Tarball..."

  build_qt_linux
  ./tarball.sh

  log_success "Tarball built successfully!"
  echo -e "  Output: ${BLUE}$RELEASE_DIR/${APP_NAME}-${VERSION}-x64-Linux.tar.gz${NC}"
}

do_build_appimage() {
  do_build_tarball

  print_section "Packaging AppImage..."
  ./appimage.sh

  log_success "AppImage built successfully!"
  echo -e "  Output: ${BLUE}$RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage${NC}"
}

do_build_android() {
  print_section "Building Android APK..."

  check_command "cmake" "Install cmake" || return 1
  # TODO: Generate open source licenses
  ./android.sh

  log_success "Android APK built successfully!"
  echo -e "  Output: ${BLUE}$RELEASE_DIR/${NC}"
}

do_build_all() {
  print_section "Building All Targets..."

  build_qt_linux

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

# Main

main() {
  print_build_header

  check_command "yq" "Install with: sudo pacman -S yq" || exit 1
  check_command "cmake" "Install cmake" || exit 1

  while true; do
    print_menu
    read -rp "Enter choice [0-6]: " choice

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
      ./clean.sh packaging
      echo ""
      read -rp "Press Enter to continue..."
      ;;
    6)
      ./clean.sh all
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
