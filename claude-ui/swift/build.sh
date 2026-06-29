#!/bin/bash
# Build the Swift native island app (no Xcode project — direct swiftc, like codex-island).
set -e
cd "$(dirname "$0")"

mkdir -p build
echo "🔨 Compiling Swift sources..."
swiftc \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Combine \
  Sources/*.swift \
  -o build/PromptCocoIsland

echo ""
echo "✅ Built: $(pwd)/build/PromptCocoIsland"
echo "▶  Run:   $(pwd)/build/PromptCocoIsland"
echo "   (kill: pkill -f PromptCocoIsland)"
