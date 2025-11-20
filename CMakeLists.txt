cmake_minimum_required(VERSION 3.12)
project(godot-litert LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set default build type
if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Debug)
endif()

# Determine target path based on platform
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(TARGET_PATH x11)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
	set(TARGET_PATH win64)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
	set(TARGET_PATH macos)
else()
	message(FATAL_ERROR "Not implemented support for ${CMAKE_SYSTEM_NAME}")
endif()

# Set output directories
set(BUILD_PATH ${CMAKE_SOURCE_DIR}/bin/${TARGET_PATH})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${BUILD_PATH}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${BUILD_PATH}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${BUILD_PATH}")

# Paths
set(GODOT_CPP_PATH ${CMAKE_SOURCE_DIR}/thirdparty/godot-cpp)
set(GODOT_GDEXTENSION_DIR ${GODOT_CPP_PATH}/gdextension CACHE STRING "Path to GDExtension interface header directory")

# Include godot-cpp
add_subdirectory(${GODOT_CPP_PATH} ${CMAKE_BINARY_DIR}/godot-cpp)

# Use LiteRT from git subrepo (no external fetch needed)
set(LITERT_PATH ${CMAKE_SOURCE_DIR}/thirdparty/litert)

message(STATUS "========================================")
message(STATUS "Using LiteRT from git subrepo")
message(STATUS "Path: ${LITERT_PATH}")
message(STATUS "========================================")

if(NOT EXISTS ${LITERT_PATH})
    message(FATAL_ERROR "LiteRT not found at ${LITERT_PATH}. Please run: git subrepo clone https://github.com/google-ai-edge/LiteRT.git thirdparty/litert -b main")
endif()

# Configure LiteRT options before including it
# Runtime-only build: Only use runtime components, not converters (per Google's guidance)
# See: https://ai.google.dev/edge/litert/build/cmake
# Enable XNNPACK for all platforms (CPU acceleration)
set(LITERT_DISABLE_XNNPACK OFF CACHE BOOL "Disable XNNPACK" FORCE)

# Disable GPU (we use xnnpack + WebGPU, not direct CUDA/Metal)
set(LITERT_ENABLE_GPU OFF CACHE BOOL "Enable GPU acceleration support" FORCE)

# Disable tools and tests (runtime-only)
set(LITERT_BUILD_TOOLS OFF CACHE BOOL "Build LiteRT tools" FORCE)
set(LITERT_BUILD_TESTS OFF CACHE BOOL "Build LiteRT tests" FORCE)

# Enable automatic TFLite build (required for first-time setup)
set(LITERT_AUTO_BUILD_TFLITE ON CACHE BOOL "Automatically build TFLite if not found" FORCE)

# Include LiteRT
message(STATUS "========================================")
message(STATUS "Configuring LiteRT...")
message(STATUS "LiteRT path: ${LITERT_PATH}/litert")
message(STATUS "XNNPACK: ENABLED")
message(STATUS "WebGPU/GPU: DISABLED")
message(STATUS "Note: LiteRT will fetch TensorFlow automatically")
message(STATUS "TensorFlow clone can take 5-10 minutes...")
message(STATUS "========================================")
add_subdirectory(${LITERT_PATH}/litert ${CMAKE_BINARY_DIR}/litert)

# Get sources
file(GLOB_RECURSE SOURCES src/*.cpp)
file(GLOB_RECURSE HEADERS src/*.h)

# Define our library
add_library(${PROJECT_NAME} SHARED ${SOURCES} ${HEADERS})

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE
	${CMAKE_SOURCE_DIR}/src
	${CMAKE_BINARY_DIR}/include  # For generated build_config.h (litert/build_common/build_config.h)
	${CMAKE_BINARY_DIR}/litert/include  # Alternative path
	${LITERT_PATH}/litert
	${LITERT_PATH}  # For litert/ includes
	${GODOT_CPP_PATH}/include
	${CMAKE_BINARY_DIR}/godot-cpp/gen/include  # Generated bindings
	${GODOT_GDEXTENSION_DIR}
)

# Compile definitions
target_compile_definitions(${PROJECT_NAME} PRIVATE
	LITERT_COMPILE_LIBRARY
)

# Compile flags
if(MSVC)
	target_compile_options(${PROJECT_NAME} PRIVATE
		/W4
		/utf-8
	)
	if(CMAKE_BUILD_TYPE MATCHES Debug)
		target_compile_options(${PROJECT_NAME} PRIVATE /MDd)
	else()
		target_compile_options(${PROJECT_NAME} PRIVATE /MD /O2)
	endif()
	target_compile_definitions(${PROJECT_NAME} PRIVATE NOMINMAX)
else()
	target_compile_options(${PROJECT_NAME} PRIVATE
		-fPIC
		-Wall
		-Wextra
	)
	if(CMAKE_BUILD_TYPE MATCHES Debug)
		target_compile_options(${PROJECT_NAME} PRIVATE -g -O0)
	else()
		target_compile_options(${PROJECT_NAME} PRIVATE -O3)
	endif()
endif()

# Determine godot-cpp library path
string(TOLOWER ${CMAKE_SYSTEM_NAME} SYSTEM_NAME_LOWER)
string(TOLOWER ${CMAKE_BUILD_TYPE} BUILD_TYPE_LOWER)
set(BITS 64)
set(GODOT_CPP_LIB_PATH "${CMAKE_BINARY_DIR}/godot-cpp/bin/libgodot-cpp.${SYSTEM_NAME_LOWER}.${BUILD_TYPE_LOWER}.${BITS}.a")

# Link libraries
# Runtime-only: Link against LiteRT runtime C API (loads/executes .tflite models)
# We do NOT link converter targets - only runtime components per Google's guidance
target_link_libraries(${PROJECT_NAME} PRIVATE
	${GODOT_CPP_LIB_PATH}
	# LiteRT runtime C API (runtime-only, no converters)
	litert_runtime_c_api_shared_lib
	# LiteRT C++ API wrapper (uses dynamic runtime)
	litert_cc_api
	# Abseil dependencies
	absl::log_internal_check_op
	absl::log_internal_format
	absl::log_internal_message
	absl::strings
	absl::log
	absl::log_flags
	absl::log_initialize
	absl::log_internal_globals
	absl::log_sink
	absl::span
	absl::flat_hash_map
)

# Set output name
set_target_properties(${PROJECT_NAME} PROPERTIES
	OUTPUT_NAME "godot_litert"
	PREFIX ""
)

# Platform-specific settings
if(APPLE)
	set_target_properties(${PROJECT_NAME} PROPERTIES
		MACOSX_BUNDLE FALSE
		MACOSX_RPATH TRUE
	)
endif()

