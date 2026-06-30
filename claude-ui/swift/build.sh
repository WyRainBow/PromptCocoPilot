#!/bin/bash
# Build the Swift native island app (no Xcode project — direct swiftc, like codex-island).
set -e
cd "$(dirname "$0")"

mkdir -p build build/Frameworks
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
