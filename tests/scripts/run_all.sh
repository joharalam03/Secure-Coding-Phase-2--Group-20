#!/bin/bash
# run_all.sh
# Purpose: Run bun_parser on all valid and invalid .bun files and save logs
# Format:
#    Testing <filename>
#    <parser output>
#    Exit code: <number> / Result: HANG (timeout)
# ---------------------------

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

mkdir -p results

VALID_DIR="tests/fixtures/valid"
INVALID_DIR="tests/fixtures/invalid"
BUN_PARSER="./target/bun_parser"

if [ ! -x "$BUN_PARSER" ]; then
    echo "Error: $BUN_PARSER not found or not executable."
    exit 1
fi

# --- VALID FILES ---

# Lecturer samples
SAMPLES_VALID_LOG="results/samples_valid.log"
> "$SAMPLES_VALID_LOG"
echo "# Lecturer sample files" >> "$SAMPLES_VALID_LOG"
echo "=== Running crafted INVALID bun files ==="
for f in "$VALID_DIR/samples"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$SAMPLES_VALID_LOG"
    "$BUN_PARSER" "$f" >> "$SAMPLES_VALID_LOG" 2>&1
    EC=$?
    echo "Exit code: $EC" >> "$SAMPLES_VALID_LOG"
    echo "---------------------------" >> "$SAMPLES_VALID_LOG"
done

# Crafted
CRAFTED_VALID_LOG="results/crafted_valid.log"
> "$CRAFTED_VALID_LOG"
echo "# Crafted test files" >> "$CRAFTED_VALID_LOG"
echo "=== Running crafted VALID bun files ==="
for f in "$VALID_DIR/crafted"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$CRAFTED_VALID_LOG"
    "$BUN_PARSER" "$f" >> "$CRAFTED_VALID_LOG" 2>&1
    EC=$?
    echo "Exit code: $EC" >> "$CRAFTED_VALID_LOG"
    echo "---------------------------" >> "$CRAFTED_VALID_LOG"
done

# --- INVALID FILES ---

# Lecturer samples
SAMPLES_INVALID_LOG="results/samples_invalid.log"
> "$SAMPLES_INVALID_LOG"
echo "# Lecturer sample files" >> "$SAMPLES_INVALID_LOG"
echo "=== Running samples INVALID bun files ==="
for f in "$INVALID_DIR/samples"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$SAMPLES_INVALID_LOG"
    timeout 5 "$BUN_PARSER" "$f" >> "$SAMPLES_INVALID_LOG" 2>&1
    EC=$?
    if [ $EC -eq 124 ]; then
        echo "Result: HANG (timeout)" >> "$SAMPLES_INVALID_LOG"
    else
        echo "Exit code: $EC" >> "$SAMPLES_INVALID_LOG"
    fi
    echo "---------------------------" >> "$SAMPLES_INVALID_LOG"
done

# Crafted
CRAFTED_INVALID_LOG="results/crafted_invalid.log"
> "$CRAFTED_INVALID_LOG"
echo "# Crafted test files" >> "$CRAFTED_INVALID_LOG"
echo "=== Running crafted INVALID bun files ==="
for f in "$INVALID_DIR/crafted"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$CRAFTED_INVALID_LOG"
    timeout 5 "$BUN_PARSER" "$f" >> "$CRAFTED_INVALID_LOG" 2>&1
    EC=$?
    if [ $EC -eq 124 ]; then
        echo "Result: HANG (timeout)" >> "$CRAFTED_INVALID_LOG"
    else
        echo "Exit code: $EC" >> "$CRAFTED_INVALID_LOG"
    fi
    echo "---------------------------" >> "$CRAFTED_INVALID_LOG"
done

echo "All tests complete. Logs are in results/"