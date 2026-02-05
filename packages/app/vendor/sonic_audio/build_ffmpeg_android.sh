#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FFMPEG_VERSION="8.0.1"
HOST_TAG="linux-x86_64"
# This is the version flutter currently uses.
TOOLCHAIN="$NDK_HOME/28.2.13676358/toolchains/llvm/prebuilt/$HOST_TAG"
API=26

function build_android {
  ARCH=$1
  CPU=$2
  CROSS_PREFIX=$3
  CC_NAME="${CROSS_PREFIX}${API}-clang"
  CXX_NAME="${CROSS_PREFIX}${API}-clang++"

  if [ "$ARCH" == "armeabi-v7a" ]; then
    CC_NAME="armv7a-linux-androideabi${API}-clang"
    CXX_NAME="armv7a-linux-androideabi${API}-clang++"
  fi

  PREFIX="$SCRIPT_DIR/ffmpeg/android/$ARCH"

  echo "Building FFmpeg for $ARCH (API $API)..."
  echo "Using compiler: $TOOLCHAIN/bin/$CC_NAME"

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
    --enable-protocol=file,http,https,hls \
    --enable-demuxer=hls,mpegts,mov,flac,mp3,ogg,wav,matroska \
    --enable-decoder=opus,flac,mp3,pcm_s16le,vorbis,aac \
    --enable-parser=opus,flac,mpegaudio,vorbis,aac \
    --enable-small --enable-cross-compile --extra-cflags="-fPIC -O2"

  make -j"$(nproc)"
  make install
  make distclean
}

# Clean previous attempts
rm -rf "ffmpeg-${FFMPEG_VERSION}"

wget -nc https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
tar xf ffmpeg-${FFMPEG_VERSION}.tar.xz

cd ffmpeg-${FFMPEG_VERSION}

build_android "arm64-v8a" "armv8-a" "aarch64-linux-android"
build_android "armeabi-v7a" "armv7-a" "armv7a-linux-androideabi"
build_android "x86_64" "x86-64" "x86_64-linux-android"

echo "Build done!"

# Cleanup on success
cd "$SCRIPT_DIR"
rm -rf "ffmpeg-${FFMPEG_VERSION}"
rm -f "ffmpeg-${FFMPEG_VERSION}.tar.xz"
echo "Cleaned up build artifacts."
