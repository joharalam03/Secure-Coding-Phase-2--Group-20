#!/usr/bin/env bash
# Compiler test runner.

set -u

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

WARNING_CFLAGS="-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -g -O2"

echo "========================================"
echo "A. Strict compiler warning build"
echo "========================================"
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

exit 0