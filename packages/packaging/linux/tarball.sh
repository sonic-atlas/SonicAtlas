#!/bin/bash
set -e
# SonicAtlas - Linux Tarball

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/../common/helpers.sh"
source ./load_config.sh

print_header "SonicAtlas Linux Tarball"

# --- Package ---

TARBALL_NAME="${APP_NAME}-${VERSION}-Linux.tar.gz"
TARBALL_PATH="$RELEASE_DIR/$TARBALL_NAME"

log_step "Creating tarball..."

STAGING_DIR="$SCRIPT_DIR/build/tarball_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

APP_STAGING_NAME="${APP_NAME}-${VERSION}"
cp -r "$BUILD_OUT" "$STAGING_DIR/$APP_STAGING_NAME"

mkdir -p "$STAGING_DIR/$APP_STAGING_NAME/assets"
cp -r "$APP_DIR/assets/icon" "$STAGING_DIR/$APP_STAGING_NAME/assets/"

tar -czf "$TARBALL_PATH" -C "$STAGING_DIR" "$APP_STAGING_NAME"

rm -rf "$STAGING_DIR"

echo ""
log_success "Tarball created successfully!"
echo -e "  Output: ${BLUE}$TARBALL_PATH${NC}"
echo ""
