# AGENTS.md

## Project Overview

This is **godot-litert**, a GDExtension for Godot Engine that integrates LiteRT (TensorFlow Lite Runtime) for on-device AI inference. The project uses **CMake** as the primary build system. We only use LiteRT runtime components (no converters) per Google's guidance: https://ai.google.dev/edge/litert/build/cmake

## Setup Commands

- **CMake**: CMake 3.12+ required
- **Python**: Python 3.9+ required for godot-cpp binding generation
- **C++ Compiler**: C++20 compatible compiler required

## Build Commands

### CMake Builds (Primary)

```bash
# Configure build
mkdir build && cd build
cmake ..

# Build
make

# Or use CMake directly
cmake --build . -j$(nproc)
```

**Runtime-Only Configuration:**
- Uses LiteRT runtime components only (no TensorFlow/JAX converters)
- Links against `litert_runtime_c_api_shared_lib` (loads/executes .tflite models)
- XNNPACK enabled for CPU acceleration
- WebGPU/GPU disabled (uses xnnpack + WebGPU, not direct CUDA/Metal)

## Project Structure

- `src/` - Main GDExtension source code (C++20)
- `CMakeLists.txt` - CMake build configuration (primary build system)
- `thirdparty/godot-cpp/` - Godot C++ bindings
- `thirdparty/litert/` - LiteRT library (runtime-only, no converters)
- `patches/` - Git patches for third-party modifications

## Key Dependencies

- **godot-cpp**: Built with CMake
- **LiteRT Runtime**: ✅ Using runtime-only components (no converters)
  - `litert_runtime_c_api_shared_lib`: Runtime C API for loading/executing .tflite models
  - `litert_cc_api`: Runtime C++ API wrapper
  - **Note**: We do NOT include TensorFlow/JAX converter code per Google's guidance

## Code Style

- **C++ Standard**: C++20
- **Naming**: Follow existing patterns in `src/` directory
- **Headers**: Include guards or `#pragma once`

## Testing Instructions

```bash
# Configure and build
mkdir build && cd build
cmake ..
cmake --build . -j$(nproc)

# Test the build
./bin/macos/godot_litert  # or appropriate path for your platform
```

## Important Files

- `CMakeLists.txt` - Main CMake build configuration
- `thirdparty/godot-cpp/CMakeLists.txt` - godot-cpp CMake configuration
- `thirdparty/litert/litert/CMakeLists.txt` - LiteRT CMake configuration

## Boundaries

- ✅ **Always do**:

  - Use CMake for builds
  - Keep patches in `patches/` directory
  - Test builds before committing

- ⚠️ **Ask first**:

  - Modifying `thirdparty/litert/` files (they're external dependencies)
  - Changing TensorFlow dependency versions

- 🚫 **Never do**:
  - Commit secrets or API keys
  - Modify `thirdparty/litert/` directly (use patches instead)
  - Remove failing tests
