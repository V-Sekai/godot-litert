# Patches

This directory contains patches for third-party dependencies.

## CMake Patches

- `tflite-cmake-use-subrepo.patch` - Patches TFLite's CMakeLists.txt to use git subrepo TensorFlow instead of FetchContent
- `litert-cmake-strip-options.patch` - Patches LiteRT's CMakeLists.txt to disable unnecessary TFLite options for faster builds

## Applying Patches

Patches are automatically applied when using git subrepo. To manually apply:

```bash
# Apply TFLite patch
git apply patches/tflite-cmake-use-subrepo.patch

# Apply LiteRT patch
git apply patches/litert-cmake-strip-options.patch
```

## Regenerating Patches

After modifying third-party files, regenerate patches with:

```bash
git diff thirdparty/litert/tflite/CMakeLists.txt > patches/tflite-cmake-use-subrepo.patch
git diff thirdparty/litert/litert/CMakeLists.txt > patches/litert-cmake-strip-options.patch
```
