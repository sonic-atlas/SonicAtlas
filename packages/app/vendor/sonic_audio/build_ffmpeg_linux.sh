#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FFMPEG_VERSION="8.0.1"
ARCH="linux-x64"
PREFIX="$(pwd)/ffmpeg/$ARCH"

rm -rf "ffmpeg-${FFMPEG_VERSION}"

wget -nc https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz
tar xf ffmpeg-${FFMPEG_VERSION}.tar.xz
cd ffmpeg-${FFMPEG_VERSION}

echo "Building FFmpeg for Linux x64..."

./configure \
  --prefix="$PREFIX" \
  --disable-gpl --disable-nonfree \
  --disable-shared --enable-static --enable-pic \
  --disable-programs --disable-doc --disable-everything \
  --disable-asm \
  --enable-protocol=file,http,https,hls,pipe \
  --enable-demuxer=hls,mpegts,mov,flac,mp3,ogg,wav,matroska \
  --enable-decoder=opus,flac,mp3,pcm_s16le,vorbis,aac \
  --enable-parser=opus,flac,mpegaudio,vorbis,aac \
  --enable-small \
  --extra-cflags="-fPIC -O2"

make -j"$(nproc)"
make install

echo "Build done! Output: $PREFIX"

cd "$SCRIPT_DIR"
rm -rf "ffmpeg-${FFMPEG_VERSION}"
rm -f "ffmpeg-${FFMPEG_VERSION}.tar.xz"
echo "Cleaned up build artifacts."
