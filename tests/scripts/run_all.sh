#!/bin/bash
# run_all.sh
# Purpose: Run bun_parser on all valid and invalid .bun files and save logs

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

echo "=== Running tests on VALID bun files ==="
> results/baseline_valid.log
for f in "$VALID_DIR"/*.bun; do
    [ -e "$f" ] || continue  # skip if no files
    echo "Testing $f" | tee -a results/baseline_valid.log
    "$BUN_PARSER" "$f" >> results/baseline_valid.log 2>&1
    echo "Exit code: $?" | tee -a results/baseline_valid.log
    echo "---------------------------" | tee -a results/baseline_valid.log
done

echo "=== Running tests on INVALID bun files ==="
> results/baseline_invalid.log
for f in "$INVALID_DIR"/*.bun; do
    [ -e "$f" ] || continue  # skip if no files
    echo "Testing $f" | tee -a results/baseline_invalid.log
    timeout 5 "$BUN_PARSER" "$f" >> results/baseline_invalid.log 2>&1
    EC=$?
    if [ $EC -eq 124 ]; then
        echo "Result: HANG (timeout)" | tee -a results/baseline_invalid.log
    else
        echo "Exit code: $EC" | tee -a results/baseline_invalid.log
    fi
    echo "---------------------------" | tee -a results/baseline_invalid.log
done

echo "All tests complete. Logs saved in results/"