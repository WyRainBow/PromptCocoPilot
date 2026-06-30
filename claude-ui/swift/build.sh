#!/bin/bash
# Build the Swift native island app (no Xcode project — direct swiftc, like codex-island).
set -e
cd "$(dirname "$0")"

mkdir -p build build/Frameworks

# --- Ensure RiveRuntime.framework is present -----------------------------------
# Bundled in the repo, but if missing (e.g. fresh clone that lost it), auto-fetch
# the official rive-app/rive-ios v6.21.0 macOS slice (checksum-pinned).
RIVE_VERSION="6.21.0"
RIVE_CHECKSUM="a44ceea0b094d22a9e16fdb94ea463411685e5a697a45d14d5d73438430ef4f8"
RIVE_ZIP_URL="https://github.com/rive-app/rive-ios/releases/download/${RIVE_VERSION}/RiveRuntime.xcframework.zip"

if [ ! -d "Frameworks/RiveRuntime.framework/Modules/RiveRuntime.swiftmodule" ]; then
  echo "⚠️  RiveRuntime.framework missing modules — fetching official rive-ios ${RIVE_VERSION}..."
  TMP_ZIP="$(mktemp -t rive).zip"
  curl -fL --max-time 180 -o "$TMP_ZIP" "$RIVE_ZIP_URL"
  ACTUAL="$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')"
  if [ "$ACTUAL" != "$RIVE_CHECKSUM" ]; then
    echo "❌ RiveRuntime checksum mismatch (got $ACTUAL)"; rm -f "$TMP_ZIP"; exit 1
  fi
  EXTRACT_DIR="$(mktemp -d -t rive)"
  unzip -q -o "$TMP_ZIP" -d "$EXTRACT_DIR"
  rm -rf Frameworks/RiveRuntime.framework
  cp -R "$EXTRACT_DIR/RiveRuntime.xcframework/macos-arm64_x86_64/RiveRuntime.framework" \
        Frameworks/RiveRuntime.framework
  rm -rf "$EXTRACT_DIR" "$TMP_ZIP"
  echo "✅ Fetched & verified RiveRuntime.framework"
fi
# -------------------------------------------------------------------------------

echo "🔨 Compiling Swift sources..."
swiftc \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Combine \
  -F "$(pwd)/Frameworks" \
  -framework RiveRuntime \
  -Xlinker -rpath -Xlinker @loader_path/Frameworks \
  Sources/*.swift \
  -o build/PromptCocoIsland

# Bundle runtime deps next to the bare executable.
echo "📦 Bundling RiveRuntime.framework + cloud asset..."
rm -rf build/Frameworks/RiveRuntime.framework
cp -R Frameworks/RiveRuntime.framework build/Frameworks/
cp Resources/*.riv build/ 2>/dev/null || true

echo ""
echo "✅ Built: $(pwd)/build/PromptCocoIsland"
echo "▶  Run:   $(pwd)/build/PromptCocoIsland"
echo "   (kill: pkill -f PromptCocoIsland)"
