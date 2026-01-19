#!/bin/bash
# SonicAtlas - Common configuration loader

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export YAML_PATH="$SCRIPT_DIR/../common/app.yaml"

# --- Validation ---
if ! command -v yq &>/dev/null; then
  echo "Error: 'yq' is required but not installed."
  echo "Install with: sudo pacman -S yq"
  exit 1
fi

get_yaml() { yq e "$1" "$YAML_PATH"; }

# --- App Metadata ---
export APP_NAME=$(get_yaml '.name')
export APP_DISPLAY=$(get_yaml '.displayName')
export APP_EXE=$(get_yaml '.exeName')
export APP_ID=$(get_yaml '.id')
export VERSION="$(get_yaml '.version.major').$(get_yaml '.version.minor').$(get_yaml '.version.patch')"

# --- Paths ---
export ROOT_DIR="$SCRIPT_DIR/../.."
export APP_DIR="$ROOT_DIR/app"
export RELEASE_DIR="$SCRIPT_DIR/../dist"
export BUILD_OUT="$APP_DIR/build/linux/x64/release/bundle"
export ANDROID_BUILD_OUT="$APP_DIR/build/app/outputs/flutter-apk"

# --- Icons ---
export ICON_PNG="$APP_DIR/assets/icon/icon.png"
export ICON_SVG="$ROOT_DIR/../assets/icon/source/icon.svg"

# --- Setup ---
mkdir -p "$RELEASE_DIR"
