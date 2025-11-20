#!/bin/bash
# Development build script for godot-litert

set -e

# Create build directory
mkdir -p build
cd build

# Configure with CMake (Debug build)
cmake .. -DCMAKE_BUILD_TYPE=Debug

# Build
cmake --build . -j$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

# Copy library to bin directory
mkdir -p ../bin/macos
cp libgodot_litert.dylib ../bin/macos/libgodot_litert.macos.template_release.universal.dylib 2>/dev/null || true
cp libgodot_litert.so ../bin/x11/libgodot_litert.linux.template_release.x86_64.so 2>/dev/null || true
cp libgodot_litert.dll ../bin/win64/libgodot_litert.windows.template_release.x86_64.dll 2>/dev/null || true

echo "Development build complete!"

