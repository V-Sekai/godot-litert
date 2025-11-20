#!/bin/bash
# Apply patches to third-party dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCHES_DIR="$PROJECT_ROOT/patches"

cd "$PROJECT_ROOT"

echo "Applying patches from $PATCHES_DIR..."

if [ -f "$PATCHES_DIR/tflite-cmake-use-subrepo.patch" ]; then
    echo "Applying TFLite CMakeLists.txt patch..."
    git apply "$PATCHES_DIR/tflite-cmake-use-subrepo.patch" || echo "Patch may already be applied or failed"
fi

if [ -f "$PATCHES_DIR/litert-cmake-strip-options.patch" ]; then
    echo "Applying LiteRT CMakeLists.txt patch..."
    git apply "$PATCHES_DIR/litert-cmake-strip-options.patch" || echo "Patch may already be applied or failed"
fi

echo "Patches applied."

