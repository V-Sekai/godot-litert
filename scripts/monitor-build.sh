#!/bin/bash
# Monitor both main build log and LiteRT logs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Monitoring build logs..."
echo "Main log: build-test.log"
echo "LiteRT log: build-litert.log (if exists)"
echo ""
echo "Press Ctrl+C to stop"
echo "================================"
echo ""

# Monitor main log
if [ -f "build-test.log" ]; then
    tail -f build-test.log &
    TAIL_PID=$!
    
    # Also check for LiteRT specific logs
    if [ -f "build-litert.log" ]; then
        tail -f build-litert.log &
        LITERT_TAIL_PID=$!
    fi
    
    # Wait for user interrupt
    trap "kill $TAIL_PID $LITERT_TAIL_PID 2>/dev/null; exit" INT TERM
    wait
else
    echo "build-test.log not found. Waiting for it to be created..."
    while [ ! -f "build-test.log" ]; do
        sleep 1
    done
    tail -f build-test.log
fi

