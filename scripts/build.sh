#!/bin/bash
# OpenGrid Build Script - WASM + Flutter Web
# Usage: ./scripts/build.sh [dev|release]

set -e

MODE=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🎮 OpenGrid Build - Mode: $MODE"
echo "================================"

# Check for Rust/cargo
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust not found. Install from https://rustup.rs/"
    exit 1
fi

# Check for wasm-pack
if ! command -v wasm-pack &> /dev/null; then
    echo "📦 Installing wasm-pack..."
    cargo install wasm-pack
fi

# Build WASM
echo ""
echo "🦀 Building WASM module..."
cd "$PROJECT_ROOT/wasm"

if [ "$MODE" = "release" ]; then
    wasm-pack build --target web --out-dir ../client/web/assets --release
else
    wasm-pack build --target web --out-dir ../client/web/assets --dev
fi

echo "✅ WASM build complete"

# Build Flutter
echo ""
echo "🎯 Building Flutter Web..."
cd "$PROJECT_ROOT/client"

if [ "$MODE" = "release" ]; then
    flutter build web --release
else
    flutter build web --profile
fi

echo ""
echo "🚀 Build complete!"
echo "   Output: client/build/web/"
echo ""
echo "To run locally:"
echo "   cd client && flutter run -d chrome"
