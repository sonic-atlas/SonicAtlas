#!/bin/bash
set -e
# SonicAtlas - Android APK Builder (Split per ABI)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/../common/helpers.sh"
source ./load_config.sh

log_info "Building Android APKs for $APP_DISPLAY v$VERSION"

# --- Validation ---

check_command "flutter" "Install from: https://flutter.dev" || exit 1

KEYSTORE="$APP_DIR/android/app/release-keystore.jks"
KEY_PROPS="$APP_DIR/android/key.properties"

if [ ! -f "$KEYSTORE" ]; then
  log_error "Release keystore not found: $KEYSTORE"
  echo "Please create a release keystore for signing."
  exit 1
fi

if [ ! -f "$KEY_PROPS" ]; then
  log_error "Key properties not found: $KEY_PROPS"
  echo "Please create key.properties with signing configuration."
  exit 1
fi

log_success "Signing keys found"

# --- Build ---

log_step "Running Flutter build..."
cd "$APP_DIR"
flutter build apk --release --split-per-abi
cd "$SCRIPT_DIR"

# --- Copy APKs ---

log_step "Copying APKs to release directory..."

APK_DIR="$ANDROID_BUILD_OUT"

if [ ! -d "$APK_DIR" ]; then
  log_error "APK output directory not found at $APK_DIR"
  exit 1
fi

ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")

for abi in "${ABIS[@]}"; do
  APK_FILE="$APK_DIR/app-${abi}-release.apk"
  if [ -f "$APK_FILE" ]; then
    OUTPUT_NAME="${APP_NAME}-${VERSION}-${abi}.apk"
    cp "$APK_FILE" "$RELEASE_DIR/$OUTPUT_NAME"
    log_success "$OUTPUT_NAME"
  else
    log_warning "APK for $abi not found (may be disabled in build config)"
  fi
done

echo ""
log_success "Android APKs built successfully!"
echo -e "  Output directory: ${BLUE}$RELEASE_DIR${NC}"
