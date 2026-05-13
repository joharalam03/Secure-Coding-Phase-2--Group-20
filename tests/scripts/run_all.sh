#!/bin/bash
# run_all.sh

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

# --- Finding 3 summary log ---
SUMMARY_LOG="results/finding3_summary.log"
> "$SUMMARY_LOG"
echo "# Finding 3: stdout vs stderr violations" >> "$SUMMARY_LOG"

# --- Helper: check stdout vs stderr ---
check_stdout_violation() {
    bunfile=$1

    tmp_out=$(mktemp)
    tmp_err=$(mktemp)

    timeout 5 "$BUN_PARSER" "$bunfile" > "$tmp_out" 2> "$tmp_err"
    EC=$?

    if [ $EC -eq 124 ]; then
        echo "$bunfile → HANG (timeout)" >> "$SUMMARY_LOG"
    else
        if grep -qiE "malformed|unsupported" "$tmp_out"; then
            echo "$bunfile → violation printed to STDOUT" >> "$SUMMARY_LOG"
        elif grep -qiE "malformed|unsupported" "$tmp_err"; then
            echo "$bunfile → correct (STDERR)" >> "$SUMMARY_LOG"
        else
            echo "$bunfile → no violation message detected" >> "$SUMMARY_LOG"
        fi
    fi

    rm -f "$tmp_out" "$tmp_err"
}

# --- VALID FILES ---

SAMPLES_VALID_LOG="results/samples_valid.log"
> "$SAMPLES_VALID_LOG"
echo "# Lecturer sample files" >> "$SAMPLES_VALID_LOG"

for f in "$VALID_DIR/samples"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$SAMPLES_VALID_LOG"
    "$BUN_PARSER" "$f" >> "$SAMPLES_VALID_LOG" 2>&1
    EC=$?
    echo "Exit code: $EC" >> "$SAMPLES_VALID_LOG"
    echo "---------------------------" >> "$SAMPLES_VALID_LOG"

    # Finding 3 check
    check_stdout_violation "$f"
done

CRAFTED_VALID_LOG="results/crafted_valid.log"
> "$CRAFTED_VALID_LOG"
echo "# Crafted test files" >> "$CRAFTED_VALID_LOG"

for f in "$VALID_DIR/crafted"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$CRAFTED_VALID_LOG"
    "$BUN_PARSER" "$f" >> "$CRAFTED_VALID_LOG" 2>&1
    EC=$?
    echo "Exit code: $EC" >> "$CRAFTED_VALID_LOG"
    echo "---------------------------" >> "$CRAFTED_VALID_LOG"

    # Finding 3 check
    check_stdout_violation "$f"
done

# --- INVALID FILES ---

SAMPLES_INVALID_LOG="results/samples_invalid.log"
> "$SAMPLES_INVALID_LOG"
echo "# Lecturer sample files" >> "$SAMPLES_INVALID_LOG"

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

    # Finding 3 check
    check_stdout_violation "$f"
done

CRAFTED_INVALID_LOG="results/crafted_invalid.log"
> "$CRAFTED_INVALID_LOG"
echo "# Crafted test files" >> "$CRAFTED_INVALID_LOG"

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

    # Finding 3 check
    check_stdout_violation "$f"
done

echo "All tests complete. Logs are in results/"