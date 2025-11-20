#!/bin/bash
# Build script with logging for tail -f monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/build-test.log"
LITERT_LOG_FILE="$PROJECT_ROOT/build-litert.log"

cd "$PROJECT_ROOT"

# Clear previous logs
> "$LOG_FILE"
> "$LITERT_LOG_FILE"

echo "=== Build Test Started at $(date) ===" | tee -a "$LOG_FILE"
echo "Project root: $PROJECT_ROOT" | tee -a "$LOG_FILE"
echo "Main log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "LiteRT log file: $LITERT_LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Configure CMake
echo "=== Configuring CMake ===" | tee -a "$LOG_FILE"
cmake -B build -DCMAKE_BUILD_TYPE=Release -DLITERT_DISABLE_XNNPACK=ON 2>&1 | tee -a "$LOG_FILE" | tee -a "$LITERT_LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Building (this includes LiteRT and TFLite builds) ===" | tee -a "$LOG_FILE"
# Build with verbose output to capture LiteRT/TFLite logs
cmake --build build --parallel --verbose 2>&1 | tee -a "$LOG_FILE" | tee -a "$LITERT_LOG_FILE"

# Also capture any log files from LiteRT/TFLite build directories
echo "" | tee -a "$LOG_FILE"
echo "=== Checking for LiteRT/TFLite log files ===" | tee -a "$LOG_FILE"
if [ -d "build/litert" ]; then
    find build/litert -name "*.log" -o -name "CMakeOutput.log" -o -name "CMakeError.log" 2>/dev/null | while read logfile; do
        echo "Found log: $logfile" | tee -a "$LOG_FILE"
        echo "=== Contents of $logfile ===" | tee -a "$LITERT_LOG_FILE"
        cat "$logfile" >> "$LITERT_LOG_FILE" 2>/dev/null || true
    done
fi

if [ -d "build/litert/tflite_build" ]; then
    find build/litert/tflite_build -name "*.log" -o -name "CMakeOutput.log" -o -name "CMakeError.log" 2>/dev/null | while read logfile; do
        echo "Found TFLite log: $logfile" | tee -a "$LOG_FILE"
        echo "=== Contents of $logfile ===" | tee -a "$LITERT_LOG_FILE"
        cat "$logfile" >> "$LITERT_LOG_FILE" 2>/dev/null || true
    done
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Build Test Completed at $(date) ===" | tee -a "$LOG_FILE"
echo "Main log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "LiteRT log: $LITERT_LOG_FILE" | tee -a "$LOG_FILE"

