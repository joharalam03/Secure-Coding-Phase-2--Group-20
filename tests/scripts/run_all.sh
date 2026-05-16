#!/bin/bash
# run_all.sh - full test suite with live crafted fail highlighting

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

run_crafted_test() {
    bunfile=$1
    expected=$2
    logfile=$3

    tmp_out=$(mktemp)
    tmp_err=$(mktemp)

    timeout 5 "$BUN_PARSER" "$bunfile" > "$tmp_out" 2> "$tmp_err"
    EC=$?

    cat "$tmp_out" >> "$logfile"
    cat "$tmp_err" >> "$logfile"

    # Highlight fails in terminal
    if [ "$expected" == "valid" ] && [ $EC -ne 0 ]; then
        echo -e "\033[0;31m[FAIL] $bunfile expected valid, got exit code $EC\033[0m"
    elif [ "$expected" == "invalid" ] && [ $EC -eq 0 ]; then
        echo -e "\033[0;31m[FAIL] $bunfile expected invalid, got exit code 0\033[0m"
    fi

    # --- partial-invalid logic ---
    if [[ "$(basename "$bunfile")" == partial_invalid* ]]; then

        asset_count=$(grep -c "Asset [0-9]\+:" "$tmp_out" || true)
        violation_count=$(grep -cE "outside|malformed|unsupported" "$tmp_out" || true)

        asset_count=${asset_count:-0}
        violation_count=${violation_count:-0}

        if [ "$asset_count" -eq 0 ]; then
            echo -e "\033[0;31m[FAIL] $bunfile: NO assets recovered\033[0m"

        elif [ "$violation_count" -le 1 ]; then
            echo -e "\033[0;33m[WARN] $bunfile: likely FAIL-FAST (violations=$violation_count)\033[0m"

        else
            echo -e "\033[0;32m[OK] $bunfile: recovered=$asset_count violations=$violation_count\033[0m"
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
done

# --- CRAFTED VALID FILES ---

CRAFTED_VALID_LOG="results/crafted_valid.log"
> "$CRAFTED_VALID_LOG"
echo "# Crafted valid test files" >> "$CRAFTED_VALID_LOG"

for f in "$VALID_DIR/crafted"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$CRAFTED_VALID_LOG"
    run_crafted_test "$f" "valid" "$CRAFTED_VALID_LOG"
    echo "---------------------------" >> "$CRAFTED_VALID_LOG"

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
    check_stdout_violation "$f"
done

# --- CRAFTED INVALID FILES ---

CRAFTED_INVALID_LOG="results/crafted_invalid.log"
> "$CRAFTED_INVALID_LOG"
echo "# Crafted invalid test files" >> "$CRAFTED_INVALID_LOG"

for f in "$INVALID_DIR/crafted"/*.bun; do
    [ -e "$f" ] || continue
    echo "Testing $f" >> "$CRAFTED_INVALID_LOG"
    run_crafted_test "$f" "invalid" "$CRAFTED_INVALID_LOG"
    echo "---------------------------" >> "$CRAFTED_INVALID_LOG"
    check_stdout_violation "$f"
done

echo "All tests complete. Logs are in results/"