# F3: Findings

## F-01

- **Category:** Incorrect output
- **Description:** For malformed input `tests/fixtures/invalid/crafted/bad_align_single_asset.bun`, the parser prints violation diagnostics to `stdout` instead of `stderr`.
- **Spec reference:** Phase 1 brief, section 5.2(d): invalid-file violations must be output on standard error.
- **Assumptions:** Standard error means `stderr` stream, separate from normal output stream (`stdout`).
- **Reproduction:**
  - `./target/bun_parser tests/fixtures/invalid/crafted/bad_align_single_asset.bun >out.txt 2>err.txt; echo $?`
- **Expected behavior:** Violation messages appear on `stderr`; non-zero exit for malformed file.
- **Actual behavior:** `stdout` contains malformed/violation output, `stderr` is empty, exit code is `1`.


## F-02

- **Category:** Incorrect output
- **Description:** `tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun` is accepted as valid (`BUN_OK`) even though RLE uncompressed size does not match the declared `uncompressed_size`.
- **Spec reference:** BUN spec section 5.1(4): if compression is used and actual uncompressed size differs from `uncompressed_size`, parser must return `BUN_MALFORMED`.
- **Assumptions:** The generator-crafted file correctly represents compressed RLE data with a declared size mismatch.
- **Reproduction:**
  - `./target/bun_parser tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun >out.txt 2>err.txt; echo $?`
- **Expected behavior:** Parser reports a violation and exits with `1` (`BUN_MALFORMED`).
- **Actual behavior:** No violation message is emitted; parser prints normal parsed output and exits with `0` (`BUN_OK`).

## F-03

- **Category:** Incorrect output
- **Description:** `tests/fixtures/invalid/crafted/uncompressed_bad_size.bun` is accepted as valid (`BUN_OK`) even though `compression == 0` and `uncompressed_size` is non-zero.
- **Spec reference:** BUN spec section 5.1(1): when `compression == 0`, `uncompressed_size` must be zero.
- **Assumptions:** A non-zero `uncompressed_size` in uncompressed mode is always malformed under section 5.1(1).
- **Reproduction:**
  - `./target/bun_parser tests/fixtures/invalid/crafted/uncompressed_bad_size.bun >out.txt 2>err.txt; echo $?`
- **Expected behavior:** Parser reports a violation and exits with `1` (`BUN_MALFORMED`).
- **Actual behavior:** No violation message is emitted; parser prints normal parsed output and exits with `0` (`BUN_OK`).
