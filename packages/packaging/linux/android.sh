#!/bin/bash
set -e
# SonicAtlas - Android APK Builder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/../common/helpers.sh"
source ./load_config.sh

log_info "Building Android APK for $APP_DISPLAY v$VERSION"

# --- Validation ---

check_command "cmake" "Install cmake" || exit 1

ENV_SH="$SCRIPT_DIR/env.sh"
if [ ! -f "$ENV_SH" ]; then
  log_error "$ENV_SH not found."
  log_error "Create it with the variables: QT_ANDROID_KEYSTORE_PATH, QT_ANDROID_KEYSTORE_ALIAS,"
  log_error "  QT_ANDROID_KEYSTORE_STORE_PASS, QT_ANDROID_KEYSTORE_KEY_PASS"
  exit 1
fi
log_info "Sourcing local environment from env.sh"
source "$ENV_SH"

signing_missing=0
if [ -z "${QT_ANDROID_KEYSTORE_PATH:-}" ]; then
  log_error "QT_ANDROID_KEYSTORE_PATH not set"
  signing_missing=1
fi
if [ -z "${QT_ANDROID_KEYSTORE_ALIAS:-}" ]; then
  log_error "QT_ANDROID_KEYSTORE_ALIAS not set"
  signing_missing=1
fi
if [ -z "${QT_ANDROID_KEYSTORE_STORE_PASS:-}" ]; then
  log_error "QT_ANDROID_KEYSTORE_STORE_PASS not set"
  signing_missing=1
fi
if [ -z "${QT_ANDROID_KEYSTORE_KEY_PASS:-}" ]; then
  log_error "QT_ANDROID_KEYSTORE_KEY_PASS not set"
  signing_missing=1
fi

if [ "$signing_missing" -eq 1 ]; then
  log_error "Signing required for android-release but some env vars are missing."
  log_error "See above which ones are missing."
  exit 1
fi

if [ ! -f "$QT_ANDROID_KEYSTORE_PATH" ]; then
  log_error "Keystore file not found: $QT_ANDROID_KEYSTORE_PATH"
  exit 1
fi

log_success "Signing configured (keystore: $QT_ANDROID_KEYSTORE_PATH, alias: $QT_ANDROID_KEYSTORE_ALIAS)"

# --- Build ---

log_step "Building Qt Android release APK..."
cd "$APP_DIR"
cmake --preset android-release
cmake --build --preset android-release
cd "$SCRIPT_DIR"

# --- Copy APK ---

log_step "Copying APK to release directory..."

MAIN_APK="$ANDROID_BUILD_OUT/android-build/SonicAtlas.apk"
OUTPUT_NAME="${APP_NAME}-${VERSION}-android.apk"

if [ -f "$MAIN_APK" ]; then
  cp "$MAIN_APK" "$RELEASE_DIR/$OUTPUT_NAME"
  log_success "Copied $OUTPUT_NAME"
else
  log_error "APK not found at $MAIN_APK"
  exit 1
fi

echo ""
log_success "Android APK built successfully!"
echo -e "  Output directory: ${BLUE}$RELEASE_DIR${NC}"
