#!/bin/bash
set -e
# SonicAtlas - AppImage Builder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/../common/helpers.sh"
source ./load_config.sh

log_info "Creating AppImage for $APP_DISPLAY v$VERSION"

# --- Validation ---

if [ ! -f "$BUILD_OUT/$APP_EXE" ]; then
  log_error "Flutter build not found at $BUILD_OUT"
  echo "Please run 'flutter build linux --release' first."
  exit 1
fi

# --- Setup AppDir ---

APPDIR="$SCRIPT_DIR/build/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

log_step "Copying Flutter bundle..."

cp -r "$BUILD_OUT/." "$APPDIR/"

mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPDIR/usr/share/metainfo"

# --- Icon ---

check_command "rsvg-convert" "Install with: sudo pacman -S librsvg" || exit 1

mkdir -p "$APPDIR/assets"
cp -r "$APP_DIR/assets/icon" "$APPDIR/assets/"

rsvg-convert -w 256 -h 256 "$ICON_SVG" -o "$APPDIR/usr/share/icons/hicolor/256x256/apps/${APP_EXE}.png"
rsvg-convert -w 256 -h 256 "$ICON_SVG" -o "$APPDIR/${APP_EXE}.png"

# --- Desktop Entry ---
DESKTOP_FILE="${APP_ID}.desktop"
TEMPLATE_DIR="$SCRIPT_DIR/config"
sed -e "s/{{APP_DISPLAY}}/$APP_DISPLAY/g" \
  -e "s/{{APP_EXE}}/$APP_EXE/g" \
  -e "s/{{APP_ID}}/$APP_ID/g" \
  "$TEMPLATE_DIR/app.desktop.template" >"$APPDIR/usr/share/applications/$DESKTOP_FILE"

cp "$APPDIR/usr/share/applications/$DESKTOP_FILE" "$APPDIR/"

# --- AppStream Metadata ---

sed -e "s/{{APP_ID}}/$APP_ID/g" \
  -e "s/{{APP_DISPLAY}}/$APP_DISPLAY/g" \
  -e "s/{{APP_EXE}}/$APP_EXE/g" \
  -e "s/{{VERSION}}/$VERSION/g" \
  -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" \
  "$TEMPLATE_DIR/app.metainfo.xml.template" >"$APPDIR/usr/share/metainfo/${APP_ID}.appdata.xml"
  
# --- AppRun ---

cat >"$APPDIR/AppRun" <<'APPRUN_EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
cd "${HERE}"
exec "./${APP_EXE}" "$@"
APPRUN_EOF

sed -i "s/\${APP_EXE}/$APP_EXE/g" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

# --- Build ---

log_step "Building AppImage..."

APPIMAGETOOL="$SCRIPT_DIR/build/appimagetool"

if ! command -v appimagetool &>/dev/null && [ ! -x "$APPIMAGETOOL" ]; then
  log_step "Downloading appimagetool..."
  curl -L -o "$APPIMAGETOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

if command -v appimagetool &>/dev/null; then
  ARCH=x86_64 appimagetool "$APPDIR" "$RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage"
else
  ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$RELEASE_DIR/${APP_NAME}-${VERSION}.AppImage"
fi

log_success "AppImage created: $RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage"
