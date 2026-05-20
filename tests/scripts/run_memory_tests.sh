#!/usr/bin/env bash

set -u

mkdir -p results
mkdir -p tests/fixtures/memory

LOG="results/memory_tests.log"

{
    echo "# Memory handling tests"
    echo
    echo "Purpose:"
    echo "These tests check whether the target parser uses excessive memory when given files with large attacker-controlled metadata values."
    echo
} > "$LOG"

echo "[INFO] Generating memory stress fixtures..."

python3 tests/generators/bunfile_generator.py \
  --out tests/fixtures/memory/rle_huge_uncompressed.bun \
  --compression rle \
  --asset-payload "AAAA" \
  --uncompressed-size 2000000000

python3 tests/generators/bunfile_generator.py \
  --out tests/fixtures/memory/huge_data_section.bun \
  --compression none \
  --asset-payload "AAAA"

python3 - <<'PY'
from pathlib import Path
import struct

p = Path("tests/fixtures/memory/huge_data_section.bun")
data = bytearray(p.read_bytes())
data[44:52] = struct.pack("<Q", 2_000_000_000)
p.write_bytes(data)
PY

python3 tests/generators/bunfile_generator.py \
  --out tests/fixtures/memory/huge_asset_count.bun \
  --compression none \
  --asset-payload "AAAA"

python3 - <<'PY'
from pathlib import Path
import struct

p = Path("tests/fixtures/memory/huge_asset_count.bun")
data = bytearray(p.read_bytes())
data[8:12] = struct.pack("<I", 100_000_000)
p.write_bytes(data)
PY

run_mem_test() {
    name="$1"
    file="$2"

    echo "[INFO] Running $name"
    echo "## $name" >> "$LOG"
    echo "File: $file" >> "$LOG"

    /usr/bin/time -v timeout 5 ./target/bun_parser "$file" \
      > "results/${name}.out" \
      2> "results/${name}.time"

    status=$?

    echo "Exit status: $status" >> "$LOG"
    grep "Maximum resident set size" "results/${name}.time" >> "$LOG" || true
    echo >> "$LOG"
}

run_mem_test "mem_rle_huge_uncompressed" "tests/fixtures/memory/rle_huge_uncompressed.bun"
run_mem_test "mem_huge_data_section" "tests/fixtures/memory/huge_data_section.bun"
run_mem_test "mem_huge_asset_count" "tests/fixtures/memory/huge_asset_count.bun"

echo "[OK] Memory tests complete. Log written to $LOG"