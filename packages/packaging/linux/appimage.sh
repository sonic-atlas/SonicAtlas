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
  log_error "Qt build not found at $BUILD_OUT"
  echo "Please run 'cmake --preset gcc-release && cmake --build --preset gcc-release' first."
  exit 1
fi

check_command "patchelf" "Install patchelf" || exit 1
check_command "rsvg-convert" "Install librsvg" || exit 1
check_command "ldd" "Install glibc or similar" || exit 1

QTPATHS="$(command -v qtpaths6 || echo /usr/lib/qt6/bin/qtpaths6)"
QT_PLUGINS_DIR="${QT6_PLUGINS_DIR:-$("$QTPATHS" --plugin-dir 2>/dev/null || echo /usr/lib/qt6/plugins)}"
QT_QML_DIR="${QT6_QML_DIR:-$("$QTPATHS" --paths Qml2Imports 2>/dev/null || echo /usr/lib/qt6/qml)}"

log_info "Qt plugins: $QT_PLUGINS_DIR"
log_info "Qt qml:     $QT_QML_DIR"

# --- Setup AppDir ---

APPDIR="$SCRIPT_DIR/build/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib"

lib_is_denied() {
  case "$(basename "$1")" in
  ld-linux* | ld-*.so* | libc.so* | libc-*.so* | libm.so* | libm-*.so* | libpthread*.so* | libdl.so* | libdl-*.so* | librt.so* | librt-*.so* | libresolv*.so* | libutil*.so* | libcrypt*.so* | libanl*.so* | libBrokenGL*.so*) return 0 ;;
  libX[A-Z]*.so*) return 0 ;;
  libxcb*.so*) return 0 ;;
  libwayland*.so*) return 0 ;;
  libGL*.so* | libEGL*.so* | libGLES*.so* | libglapi.so* | libgallium*.so* | libgbm.so* | libdrm.so*) return 0 ;;
  libfontconfig.so* | libfreetype.so* | libharfbuzz*.so* | libfribidi.so*) return 0 ;;
  esac
  return 1
}

# Set rpath on $1 (absolute path inside AppDir) to point at $2 (absolute lib dir).
set_rpath() {
  local file="$1" libdir="$2"
  local filedir rel
  filedir="$(dirname "$file")"
  rel="$(realpath --relative-to="$filedir" "$libdir" 2>/dev/null)"
  [ -n "$rel" ] || return 0
  patchelf --force --set-rpath "\$ORIGIN/$rel" "$file" 2>/dev/null || true
}

# Copy non-denied deps of $1 (an ELF file) into $APPDIR/usr/lib and patch their rpath.
# ldd gives the full transitive closure of linked libs 
bundle_libs_for() {
  local elf="$1"
  [ -f "$elf" ] || return 0
  ldd "$elf" 2>/dev/null | awk '/=> \// {print $3} /^[[:space:]]*\// {print $1}' | sort -u | while read -r lib; do
    [ -f "$lib" ] || continue
    if lib_is_denied "$lib"; then continue; fi
    local dest="$APPDIR/usr/lib/$(basename "$lib")"
    if [ ! -e "$dest" ]; then
      cp -L "$lib" "$dest"
      set_rpath "$dest" "$APPDIR/usr/lib"
    fi
  done
}

# --- Install binary + bundle libraries ---

log_step "Installing binary and bundling linked libraries..."
install -Dm755 "$BUILD_OUT/$APP_EXE" "$APPDIR/usr/bin/$APP_EXE"
bundle_libs_for "$APPDIR/usr/bin/$APP_EXE"
set_rpath "$APPDIR/usr/bin/$APP_EXE" "$APPDIR/usr/lib"

log_step "Bundling Qt plugins (allow-list)..."
QT_PLUGIN_ALLOWLIST=(
  "platforms/libqxcb.so"
  "platforms/libqwayland.so"
  "imageformats/libqgif.so"
  "imageformats/libqjpeg.so"
  "imageformats/libqsvg.so"
  "imageformats/libqwebp.so"
  "tls/libqcertonlybackend.so"
  "tls/libqopensslbackend.so"
)

for rel in "${QT_PLUGIN_ALLOWLIST[@]}"; do
  src="$QT_PLUGINS_DIR/$rel"
  if [ -f "$src" ]; then
    dest="$APPDIR/usr/lib/qt6/plugins/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -L "$src" "$dest"
    bundle_libs_for "$dest"
    set_rpath "$dest" "$APPDIR/usr/lib"
  else
    log_warning "Qt plugin not found, skipping: $rel"
  fi
done

log_step "Bundling QML modules (allow-list)..."
mkdir -p "$APPDIR/usr/lib/qt6/qml"
QT_QML_ALLOWLIST_DIRS=("QtQml" "QtQuick")
for rel in "${QT_QML_ALLOWLIST_DIRS[@]}"; do
  src="$QT_QML_DIR/$rel"
  if [ -d "$src" ]; then
    cp -rL "$src" "$APPDIR/usr/lib/qt6/qml/"
  else
    log_warning "QML module not found, skipping: $rel"
  fi
done
.
find "$APPDIR/usr/lib/qt6/qml" -type f -name '*.so' -print0 | while IFS= read -r -d '' so; do
  bundle_libs_for "$so"
  set_rpath "$so" "$APPDIR/usr/lib"
done

cat >"$APPDIR/usr/bin/qt.conf" <<'QTCONF_EOF'
[Paths]
Prefix = ..
Plugins = lib/qt6/plugins
Qml2Imports = lib/qt6/qml
QTCONF_EOF

# Safety for kde image plugins 
kimg_hits="$(find "$APPDIR" -name 'kimg_*.so' -print 2>/dev/null || true)"
if [ -n "$kimg_hits" ]; then
  log_warning "Purging bundled kimg_*.so (host KDE image plugins):"
  echo "$kimg_hits" | while read -r f; do rm -f "$f"; done
fi

mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPDIR/usr/share/metainfo"

# --- Icon ---

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
ln -s "usr/bin/$APP_EXE" "$APPDIR/AppRun"

# --- AppStream Metadata ---

sed -e "s/{{APP_ID}}/$APP_ID/g" \
  -e "s/{{APP_DISPLAY}}/$APP_DISPLAY/g" \
  -e "s/{{APP_EXE}}/$APP_EXE/g" \
  -e "s/{{VERSION}}/$VERSION/g" \
  -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" \
  "$TEMPLATE_DIR/app.metainfo.xml.template" >"$APPDIR/usr/share/metainfo/${APP_ID}.appdata.xml"

# --- Build AppImage ---

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
  ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage"
fi

log_success "AppImage created: $RELEASE_DIR/${APP_NAME}-${VERSION}-x64.AppImage"
