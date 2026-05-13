#!/bin/bash
# run_all.sh
# Purpose: Run bun_parser on all valid and invalid .bun files and save logs
# Note: Logs for lecturer samples include a header comment stating they are official samples.

# Ensure we are in the Phase2 root directory
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

# Create results folder if it doesn't exist
mkdir -p results

# Define paths
VALID_DIR="tests/fixtures/valid"
INVALID_DIR="tests/fixtures/invalid"
BUN_PARSER="./target/bun_parser"

# Check that bun_parser exists
if [ ! -x "$BUN_PARSER" ]; then
    echo "Error: $BUN_PARSER not found or not executable."
    exit 1
fi

# --- VALID FILES ---
echo "=== Running tests on VALID bun files ==="

VALID_LOG="results/samples_valid.log"
> "$VALID_LOG"
echo "# Note: The following files are lecturer-provided samples" >> "$VALID_LOG"

for sub in lecturer_samples crafted; do
    for f in "$VALID_DIR/$sub"/*.bun; do
        [ -e "$f" ] || continue  # skip if no files
        echo "Testing $f" | tee -a "$VALID_LOG"
        "$BUN_PARSER" "$f" >> "$VALID_LOG" 2>&1
        echo "Exit code: $?" | tee -a "$VALID_LOG"
        echo "---------------------------" | tee -a "$VALID_LOG"
    done
done

# --- INVALID FILES ---
echo "=== Running tests on INVALID bun files ==="

INVALID_LOG="results/samples_invalid.log"
> "$INVALID_LOG"
echo "# Note: The following files are lecturer-provided samples" >> "$INVALID_LOG"

for sub in lecturer_samples crafted; do
    for f in "$INVALID_DIR/$sub"/*.bun; do
        [ -e "$f" ] || continue  # skip if no files
        echo "Testing $f" | tee -a "$INVALID_LOG"
        timeout 5 "$BUN_PARSER" "$f" >> "$INVALID_LOG" 2>&1
        EC=$?
        if [ $EC -eq 124 ]; then
            echo "Result: HANG (timeout)" | tee -a "$INVALID_LOG"
        else
            echo "Exit code: $EC" | tee -a "$INVALID_LOG"
        fi
        echo "---------------------------" | tee -a "$INVALID_LOG"
    done
done

echo "All tests complete. Logs saved in results/"