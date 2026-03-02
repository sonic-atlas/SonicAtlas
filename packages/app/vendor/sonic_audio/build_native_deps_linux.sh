#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FFMPEG_VERSION="8.0.1"
OPENSSL_VERSION="3.6.1"
ARCH="linux-x64"
PREFIX="$(pwd)/dependencies/$ARCH"

rm -rf "ffmpeg-${FFMPEG_VERSION}" "openssl-${OPENSSL_VERSION}"

echo "Building OpenSSL ${OPENSSL_VERSION} (static) for Linux x64..."

wget -nc "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
tar xf "openssl-${OPENSSL_VERSION}.tar.gz"
cd "openssl-${OPENSSL_VERSION}"

./Configure linux-x86_64 \
  --prefix="$PREFIX" \
  --libdir=lib \
  no-shared no-apps no-tests \
  no-comp no-ssl3 no-dtls \
  no-cms no-ocsp no-srp no-ts \
  no-ui-console \
  -fPIC

make -j"$(nproc)"
make install_sw

cd "$SCRIPT_DIR"
rm -rf "openssl-${OPENSSL_VERSION}"
rm -f  "openssl-${OPENSSL_VERSION}.tar.gz"
echo "OpenSSL build done."

echo "Building FFmpeg ${FFMPEG_VERSION} for Linux x64..."

wget -nc "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
tar xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
cd "ffmpeg-${FFMPEG_VERSION}"

./configure \
  --prefix="$PREFIX" \
  --disable-gpl --disable-nonfree \
  --disable-shared --enable-static --enable-pic \
  --disable-programs --disable-doc --disable-everything \
  --disable-asm \
  --enable-openssl \
  --enable-protocol=file,tcp,udp,http,https,hls,tls,pipe \
  --enable-demuxer=hls,mpegts,mov,flac,mp3,ogg,wav,matroska \
  --enable-muxer=wav \
  --enable-decoder=opus,flac,mp3,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,vorbis,aac \
  --enable-encoder=pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le \
  --enable-parser=opus,flac,mpegaudio,vorbis,aac \
  --enable-small \
  --extra-cflags="-fPIC -O2 -I${PREFIX}/include" \
  --extra-ldflags="-L${PREFIX}/lib"

make -j"$(nproc)"
make install

echo "FFmpeg build done! Output: $PREFIX"

cd "$SCRIPT_DIR"
rm -rf "ffmpeg-${FFMPEG_VERSION}"
rm -f  "ffmpeg-${FFMPEG_VERSION}.tar.xz"
echo "Cleaned up build artifacts."
