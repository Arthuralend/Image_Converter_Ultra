#!/usr/bin/env bash
# Builds cjpegli (JPEGli encoder) from libjxl sources into ./cjpegli-bin/cjpegli
# (Homebrew's jpeg-xl formula does not ship it).
set -euo pipefail
cd "$(dirname "$0")/.."
VER="${LIBJXL_VERSION:-v0.11.1}"
brew install cmake giflib libpng jpeg-turbo || true
rm -rf libjxl-src
git clone --depth 1 --branch "$VER" --recursive --shallow-submodules https://github.com/libjxl/libjxl.git libjxl-src
cmake -S libjxl-src -B libjxl-src/build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_MODULE_PATH="$PWD/scripts/cmake" \
  -DBUILD_TESTING=OFF -DJPEGXL_STATIC=ON -DJPEGXL_ENABLE_TOOLS=ON -DJPEGXL_ENABLE_JPEGLI=ON \
  -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_ENABLE_MANPAGES=OFF \
  -DJPEGXL_ENABLE_PLUGINS=OFF -DJPEGXL_ENABLE_VIEWERS=OFF -DJPEGXL_ENABLE_DOXYGEN=OFF \
  -DJPEGXL_ENABLE_SJPEG=OFF -DJPEGXL_ENABLE_OPENEXR=OFF -DJPEGXL_ENABLE_JNI=OFF \
  -DJPEGXL_ENABLE_SKCMS=ON -DJPEGXL_ENABLE_TRANSCODE_JPEG=ON \
  || { echo '--- cmake logs ---'; for f in libjxl-src/build/CMakeFiles/CMakeConfigureLog.yaml libjxl-src/build/CMakeFiles/CMakeError.log; do [ -f "$f" ] && grep -n -i -B2 -A12 "error" "$f" | tail -120; done; exit 1; }
cmake --build libjxl-src/build --target cjpegli -j"$(sysctl -n hw.ncpu)"
mkdir -p cjpegli-bin
cp libjxl-src/build/tools/cjpegli cjpegli-bin/cjpegli
./cjpegli-bin/cjpegli --help >/dev/null 2>&1 || true
echo "Built cjpegli: $(ls -l cjpegli-bin/cjpegli)"
