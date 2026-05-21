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

crafted_reproduced=0
property_reproduced=0
partial_reproduced=0

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

    if [ "$expected" == "valid" ] && [ $EC -ne 0 ]; then
        echo -e "\033[0;33m[REPRODUCED] Parser rejected valid file: $(basename "$bunfile")\033[0m"
        crafted_reproduced=$((crafted_reproduced + 1))

    elif [ "$expected" == "invalid" ] && [ $EC -eq 0 ]; then
        echo -e "\033[0;33m[REPRODUCED] Parser accepted malformed file: $(basename "$bunfile")\033[0m"
        crafted_reproduced=$((crafted_reproduced + 1))
    fi

    # --- partial-invalid logic ---
    if [[ "$(basename "$bunfile")" == partial_invalid* ]]; then

        asset_count=$(grep -c "Asset [0-9]\+:" "$tmp_out" || true)
        violation_count=$(grep -cE "outside|malformed|unsupported" "$tmp_out" || true)

        asset_count=${asset_count:-0}
        violation_count=${violation_count:-0}

        if [ "$asset_count" -eq 0 ]; then
            echo -e "\033[0;33m[REPRODUCED] No asset recovery: $(basename "$bunfile")\033[0m"
            partial_reproduced=$((partial_reproduced + 1))

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


# --- PROPERTY-BASED TESTS: compression=none requires uncompressed_size=0 ---

PROPERTY_LOG="results/property_tests.log"
> "$PROPERTY_LOG"

echo "# Property-based tests" >> "$PROPERTY_LOG"
echo "Property: compression=none requires uncompressed_size=0" >> "$PROPERTY_LOG"

PROPERTY_DIR="tests/fixtures/property/invalid"
mkdir -p "$PROPERTY_DIR"

echo "Generating property-based test files..." >> "$PROPERTY_LOG"

python3 tests/generators/bunfile_generator.py \
    --mode property-none-size \
    --out "$PROPERTY_DIR/prop_none_bad_uncompressed.bun" \
    >> "$PROPERTY_LOG" 2>&1

property_triggered=0
property_checked=0

for f in "$PROPERTY_DIR"/prop_none_bad_uncompressed_*.bun; do
    [ -e "$f" ] || continue

    property_checked=$((property_checked + 1))

    echo "Testing $f" >> "$PROPERTY_LOG"

    timeout 5 "$BUN_PARSER" "$f" >> "$PROPERTY_LOG" 2>&1
    EC=$?

    if [ $EC -eq 124 ]; then
        echo "[TRIGGERED FLAW] Parser hung for more than 5 seconds" >> "$PROPERTY_LOG"
        property_triggered=$((property_triggered + 1))
        property_reproduced=$((property_reproduced + 1))

    elif [ $EC -eq 0 ]; then
        echo "[TRIGGERED FLAW] Invalid property case accepted with exit code 0" >> "$PROPERTY_LOG"
        echo -e "\033[0;33m[REPRODUCED] Parser accepted malformed property case: $(basename "$f")\033[0m"
        property_triggered=$((property_triggered + 1))
        property_reproduced=$((property_reproduced + 1))

    else
        echo "[OK] Invalid property case rejected with exit code $EC" >> "$PROPERTY_LOG"
    fi

    echo "---------------------------" >> "$PROPERTY_LOG"
done

echo "Checked property cases: $property_checked" >> "$PROPERTY_LOG"
echo "Triggered property flaws: $property_triggered" >> "$PROPERTY_LOG"


# --- PROPERTY-BASED TESTS: RLE expanded size must match uncompressed_size ---

echo "" >> "$PROPERTY_LOG"
echo "# Property-based tests: RLE size mismatch" >> "$PROPERTY_LOG"
echo "Property: RLE expanded size must match uncompressed_size" >> "$PROPERTY_LOG"

python3 tests/generators/bunfile_generator.py \
    --mode property-rle-size \
    --out "$PROPERTY_DIR/prop_rle_bad_uncompressed.bun" \
    >> "$PROPERTY_LOG" 2>&1

for f in "$PROPERTY_DIR"/prop_rle_bad_uncompressed_*.bun; do
    [ -e "$f" ] || continue

    property_checked=$((property_checked + 1))

    echo "Testing $f" >> "$PROPERTY_LOG"

    timeout 5 "$BUN_PARSER" "$f" >> "$PROPERTY_LOG" 2>&1
    EC=$?

    if [ $EC -eq 124 ]; then
        echo "[TRIGGERED FLAW] Parser hung for more than 5 seconds" >> "$PROPERTY_LOG"
        property_triggered=$((property_triggered + 1))
        property_reproduced=$((property_reproduced + 1))

    elif [ $EC -eq 0 ]; then
        echo "[TRIGGERED FLAW] Invalid RLE property case accepted with exit code 0" >> "$PROPERTY_LOG"
        echo -e "\033[0;33m[REPRODUCED] Parser accepted malformed RLE property case: $(basename "$f")\033[0m"
        property_triggered=$((property_triggered + 1))
        property_reproduced=$((property_reproduced + 1))

    else
        echo "[OK] Invalid RLE property case rejected with exit code $EC" >> "$PROPERTY_LOG"
    fi

    echo "---------------------------" >> "$PROPERTY_LOG"
done

# --- PROPERTY-BASED TESTS: asset name must stay within string table ---

echo "" >> "$PROPERTY_LOG"
echo "# Property-based tests: asset name bounds" >> "$PROPERTY_LOG"
echo "Property: name_offset + name_length must stay within string_table_size" >> "$PROPERTY_LOG"

python3 tests/generators/bunfile_generator.py \
    --mode property-name-bounds \
    --out "$PROPERTY_DIR/prop_name_bounds.bun" \
    >> "$PROPERTY_LOG" 2>&1

for f in "$PROPERTY_DIR"/prop_name_bounds_*.bun; do
    [ -e "$f" ] || continue

    property_checked=$((property_checked + 1))

    echo "Testing $f" >> "$PROPERTY_LOG"

    timeout 5 "$BUN_PARSER" "$f" >> "$PROPERTY_LOG" 2>&1
    EC=$?

    if [ $EC -eq 124 ]; then
        echo "[TRIGGERED FLAW] Parser hung for more than 5 seconds" >> "$PROPERTY_LOG"
        echo -e "\033[0;31m[FAIL] $f expected invalid, parser hung\033[0m"
        property_triggered=$((property_triggered + 1))

    elif [ $EC -eq 0 ]; then
        echo "[TRIGGERED FLAW] Invalid name-bounds property case accepted with exit code 0" >> "$PROPERTY_LOG"
        echo -e "\033[0;31m[FAIL] $f expected invalid, got exit code 0\033[0m"
        property_triggered=$((property_triggered + 1))

    else
        echo "[OK] Invalid name-bounds property case rejected with exit code $EC" >> "$PROPERTY_LOG"
    fi

    echo "---------------------------" >> "$PROPERTY_LOG"
done

echo
echo "--------------------------------------------------"
echo "Reproduction Summary"
echo "--------------------------------------------------"
echo "Crafted flaws reproduced:   $crafted_reproduced"
echo "Property flaws reproduced: $property_reproduced"
echo "Partial recovery flaws:    $partial_reproduced"
echo
echo "[OK] Detailed logs available in results/"
echo "results/samples_valid.log  |  results/samples_invalid.log" 
echo "results/crafted_valid.log  |  results/crafted_invalid.log"
echo "results/property_tests.log"