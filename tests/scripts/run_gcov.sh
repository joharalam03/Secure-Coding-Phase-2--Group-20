#!/usr/bin/env bash

set -u

mkdir -p results

LOG="results/gcov_summary.log"

{
    echo "# GCOV coverage summary"
    echo
    echo "Purpose:"
    echo "GCOV was used to measure how much of the target parser source was exercised by our reproduction tests."
    echo
} > "$LOG"

echo "[INFO] Cleaning target build..."
cd target && make clean || true

echo "[INFO] Building target with GCOV flags..."
make CFLAGS="-std=c11 -Wall -Wextra -Wpedantic -fprofile-arcs -ftest-coverage -g -O0" || {
    echo "[FAIL] GCOV build failed" | tee -a "../$LOG"
    exit 1
}

cd ..

echo "[INFO] Running reproduction tests against GCOV build..."
bash ./tests/scripts/run_all.sh > results/gcov_test_run.log 2>&1 || true

echo "[INFO] Running one direct valid-file execution to ensure .gcda files are produced..."
./target/bun_parser tests/fixtures/valid/samples/01-empty.bun >> results/gcov_test_run.log 2>&1 || true

echo "[INFO] Running gcov..."
cd target

gcov bun_parse.c > ../results/gcov_bun_parse_raw.log 2>&1 || true
gcov main.c > ../results/gcov_main_raw.log 2>&1 || true

cd ..

{
    echo
    echo "Build flags:"
    echo "-std=c11 -Wall -Wextra -Wpedantic -fprofile-arcs -ftest-coverage -g -O0"
    echo
    echo "GCOV raw output for bun_parse.c:"
    cat results/gcov_bun_parse_raw.log
    echo
    echo "GCOV raw output for main.c:"
    cat results/gcov_main_raw.log
} >> "$LOG"

echo "[OK] GCOV run complete. Log written to $LOG"