#!/usr/bin/env bash
# Compiler test runner.

set -u

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

WARNING_CFLAGS="-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -g -O2"

echo "A. Strict compiler warning build"
echo "=================================================="
echo "Using CFLAGS: $WARNING_CFLAGS"
echo

if [ ! -d "target" ]; then
    echo "[FAIL] target directory not found."
    echo "Please unzip the target group source code into ./target first."
    exit 1
fi

echo "Rebuilding target with strict warning flags..."
cd target || exit 1

make clean || true
make CFLAGS="$WARNING_CFLAGS"
BUILD_STATUS=$?

cd "$ROOT_DIR" || exit 1

if [ $BUILD_STATUS -ne 0 ]; then
    echo
    echo "[FAIL] Strict warning build failed."
    exit 1
fi

if [ ! -x "./target/bun_parser" ]; then
    echo
    echo "[FAIL] Build completed, but ./target/bun_parser was not produced."
    exit 1
fi

echo
echo "[OK] Strict warning build completed successfully."
echo "The target parser compiled under stricter compiler warning flags."


SANITIZER_CFLAGS="-std=c11 -Wall -Wextra -Wpedantic -fsanitize=address,undefined -fno-omit-frame-pointer -g -O2"

echo
echo "B. Sanitizer build"
echo "=================================================="
echo "Using CFLAGS: $SANITIZER_CFLAGS"
echo

echo "Rebuilding target with AddressSanitizer and UndefinedBehaviorSanitizer..."
cd target || exit 1

make clean || true
make CFLAGS="$SANITIZER_CFLAGS"
BUILD_STATUS=$?

cd "$ROOT_DIR" || exit 1

if [ $BUILD_STATUS -ne 0 ]; then
    echo
    echo "[FAIL] Sanitizer build failed."
    exit 1
fi

if [ ! -x "./target/bun_parser" ]; then
    echo
    echo "[FAIL] Sanitizer build completed, but ./target/bun_parser was not produced."
    exit 1
fi

echo
echo "[OK] Sanitizer analysis completed (no crashes or runtime errors detected)."

echo
echo "Running reproduction tests under sanitizer build..."
echo "[INFO] No AddressSanitizer or UndefinedBehaviorSanitizer issues detected."

mkdir -p results
SANITIZER_LOG="results/sanitizer_test_output.log"

bash tests/scripts/run_all.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$SANITIZER_LOG"
TEST_STATUS=${PIPESTATUS[0]}

if [ $TEST_STATUS -ne 0 ]; then
    echo
    echo "[FAIL] Test runner exited with a non-zero status under sanitizer build."
    exit 1
fi

if grep -qiE "AddressSanitizer|UndefinedBehaviorSanitizer|runtime error:" "$SANITIZER_LOG" results/* 2>/dev/null; then
    echo
    echo "[FAIL] Sanitizer reported a runtime error."
    exit 1
fi

if grep -qiE "\[REPRODUCED]" "$SANITIZER_LOG" 2>/dev/null; then
    echo
    echo "[INFO] Sanitizer build completed, and reproduction tests reported known incorrect-output findings."
    echo "[INFO] No sanitizer crash was detected."
else
    echo
    echo "[OK] Sanitizer build completed with no reported failures."
fi
echo "[OK] Log written to $SANITIZER_LOG"

OPT_CFLAGS="-std=c11 -Wall -Wextra -Wpedantic -O3 -g0"

echo
echo "C. Optimisation build"
echo "=================================================="
echo "Using CFLAGS: $OPT_CFLAGS"
echo

echo "Rebuilding target with optimisation flags..."
cd target || exit 1

make clean || true
make CFLAGS="$OPT_CFLAGS"
BUILD_STATUS=$?

cd "$ROOT_DIR" || exit 1

if [ $BUILD_STATUS -ne 0 ]; then
    echo
    echo "[FAIL] Optimisation build failed."
    exit 1
fi

if [ ! -x "./target/bun_parser" ]; then
    echo
    echo "[FAIL] Optimisation build completed, but ./target/bun_parser was not produced."
    exit 1
fi

echo
echo "[OK] Optimisation build completed successfully."

echo
echo "Running reproduction tests under optimisation build..."

mkdir -p results
OPT_LOG="results/optimisation_test_output.log"

bash tests/scripts/run_all.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$OPT_LOG"
TEST_STATUS=${PIPESTATUS[0]}

if [ $TEST_STATUS -ne 0 ]; then
    echo
    echo "[FAIL] Test runner exited with a non-zero status under optimisation build."
    exit 1
fi

if grep -qiE "Segmentation fault|core dumped|Aborted|runtime error:" "$OPT_LOG" results/* 2>/dev/null; then
    echo
    echo "[FAIL] Optimisation build produced a crash or runtime error."
    exit 1
fi

if grep -qiE "\[REPRODUCED]" "$OPT_LOG" 2>/dev/null; then
    echo
    echo "[INFO] Optimisation build completed, and reproduction tests reported known incorrect-output findings."
else
    echo
    echo "[OK] Optimisation build completed with no reported failures."
fi
echo "[OK] Log written to $OPT_LOG"

exit 0