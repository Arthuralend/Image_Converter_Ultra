#!/usr/bin/env bash
# Builds "Image Compressor Ultra.app" and bundles the encoders (cjpegli, pngquant, gifsicle).
# Requires: Xcode command line tools, Homebrew.   scripts/build_cjpegli.sh  &&  brew install pngquant gifsicle dylibbundler
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Image Compressor Ultra.app"
ARCHS="--arch arm64 --arch x86_64"
swift build -c release $ARCHS || { ARCHS=""; swift build -c release; }
BIN="$(swift build -c release $ARCHS --show-bin-path)/ImageConverterUltra"

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/ImageConverterUltra"

# --- bundle encoders ---
for t in cjpegli pngquant gifsicle; do
  if [ -x "cjpegli-bin/$t" ]; then src="cjpegli-bin/$t"; else src="$(command -v "$t" || true)"; fi
  if [ -z "$src" ]; then echo "error: $t not found (cjpegli: run scripts/build_cjpegli.sh)"; exit 1; fi
  cp "$src" "$APP/Contents/Resources/bin/$t"
  if command -v dylibbundler >/dev/null; then
    dylibbundler -of -b -x "$APP/Contents/Resources/bin/$t" \
      -d "$APP/Contents/Frameworks" -p "@executable_path/../../Frameworks" >/dev/null
  fi
done

# --- icon ---
ICONSET="build/AppIcon.iconset"; rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Image Compressor Ultra</string>
  <key>CFBundleDisplayName</key><string>Image Compressor Ultra</string>
  <key>CFBundleIdentifier</key><string>com.arthuralend.ImageConverterUltra</string>
  <key>CFBundleExecutable</key><string>ImageConverterUltra</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key><array><dict>
    <key>CFBundleTypeName</key><string>Images and folders</string>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>LSItemContentTypes</key><array>
      <string>public.jpeg</string><string>public.png</string>
      <string>com.compuserve.gif</string><string>public.folder</string>
    </array>
  </dict></array>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Built: $APP"
