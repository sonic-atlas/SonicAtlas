#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FFMPEG_VERSION="8.0.1"
OPENSSL_VERSION="3.6.1"
HOST_TAG="linux-x86_64"
# This is the version flutter currently uses.
TOOLCHAIN="$NDK_HOME/28.2.13676358/toolchains/llvm/prebuilt/$HOST_TAG"
API=26

declare -A OPENSSL_TARGETS=(
  ["arm64-v8a"]="android-arm64"
  ["armeabi-v7a"]="android-arm"
  ["x86_64"]="android-x86_64"
)

function build_openssl_android {
  local ARCH=$1
  local OPENSSL_TARGET="${OPENSSL_TARGETS[$ARCH]}"
  local PREFIX="$SCRIPT_DIR/dependencies/android/$ARCH"

  echo "Building OpenSSL ${OPENSSL_VERSION} for $ARCH ($OPENSSL_TARGET)..."

  cd "$SCRIPT_DIR/openssl-${OPENSSL_VERSION}"
  make distclean 2>/dev/null || true

  export ANDROID_NDK_ROOT="$NDK_HOME/28.2.13676358"
  export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/bin:$PATH"

  ./Configure "$OPENSSL_TARGET" \
    --prefix="$PREFIX" \
    --libdir=lib \
    -D__ANDROID_API__=$API \
    no-shared no-apps no-tests \
    no-comp no-ssl3 no-dtls \
    no-cms no-ocsp no-srp no-ts \
    no-ui-console \
    -fPIC

  make -j"$(nproc)"
  make install_sw
}

function build_ffmpeg_android {
  local ARCH=$1
  local CPU=$2
  local CROSS_PREFIX=$3
  local CC_NAME="${CROSS_PREFIX}${API}-clang"
  local CXX_NAME="${CROSS_PREFIX}${API}-clang++"
  local PREFIX="$SCRIPT_DIR/dependencies/android/$ARCH"

  echo "Building FFmpeg ${FFMPEG_VERSION} for $ARCH (API $API)..."
  echo "Using compiler: $TOOLCHAIN/bin/$CC_NAME"

  cd "$SCRIPT_DIR/ffmpeg-${FFMPEG_VERSION}"
  make distclean 2>/dev/null || true

  ./configure \
    --prefix="$PREFIX" \
    --target-os=android \
    --arch="$ARCH" \
    --cpu="$CPU" \
    --cc="$TOOLCHAIN/bin/$CC_NAME" \
    --cxx="$TOOLCHAIN/bin/$CXX_NAME" \
    --ar="$TOOLCHAIN/bin/llvm-ar" \
    --nm="$TOOLCHAIN/bin/llvm-nm" \
    --ranlib="$TOOLCHAIN/bin/llvm-ranlib" \
    --strip="$TOOLCHAIN/bin/llvm-strip" \
    --disable-gpl --disable-nonfree \
    --disable-shared --enable-static --enable-pic \
    --disable-programs --disable-doc --disable-everything \
    --disable-asm \
    --enable-openssl \
    --enable-protocol=file,tcp,udp,http,https,hls,tls \
    --enable-demuxer=hls,mpegts,mov,flac,mp3,ogg,wav,matroska \
    --enable-decoder=opus,flac,mp3,pcm_s16le,vorbis,aac \
    --enable-parser=opus,flac,mpegaudio,vorbis,aac \
    --enable-small --enable-cross-compile \
    --extra-cflags="-fPIC -O2 -I${PREFIX}/include" \
    --extra-ldflags="-L${PREFIX}/lib"

  make -j"$(nproc)"
  make install
}

rm -rf "ffmpeg-${FFMPEG_VERSION}" "openssl-${OPENSSL_VERSION}"

wget -nc "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
wget -nc "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"

tar xf "openssl-${OPENSSL_VERSION}.tar.gz"
tar xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"

for abi in arm64-v8a armeabi-v7a x86_64; do
  build_openssl_android "$abi"
done

build_ffmpeg_android "arm64-v8a"    "armv8-a" "aarch64-linux-android"
build_ffmpeg_android "armeabi-v7a"  "armv7-a" "armv7a-linux-androideabi"
build_ffmpeg_android "x86_64"       "x86-64"  "x86_64-linux-android"

echo "Build done!"

cd "$SCRIPT_DIR"
rm -rf "ffmpeg-${FFMPEG_VERSION}" "openssl-${OPENSSL_VERSION}"
rm -f  "ffmpeg-${FFMPEG_VERSION}.tar.xz" "openssl-${OPENSSL_VERSION}.tar.gz"
echo "Cleaned up build artifacts."
