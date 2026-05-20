# F3: Findings

## F-01  Violation diagnostics are emitted to `stdout` instead of `stderr`

The phase brief requires that malformed inputs produce a human-readable list of violations on standard error (section 5.2(d)), while standard output is reserved for parsed file content (section 5.2(e)). During reproduction, we observed that this separation is not respected for at least one malformed crafted input: `tests/fixtures/invalid/crafted/bad_align_single_asset.bun`.

To isolate output streams, we ran the parser with separate redirections for `stdout` and `stderr` and captured the exit code:

`./target/bun_parser tests/fixtures/invalid/crafted/bad_align_single_asset.bun >out.txt 2>err.txt; echo $?`

Observed behaviour from `make reproduce` artifacts:

| Fixture | Expected exit | Actual exit | Expected stream for violations | Actual stream for violations |
|---|---:|---:|---|---|
| `bad_align_single_asset.bun` | 1 (`BUN_MALFORMED`) | 1 | `stderr` | **`stdout`** (`err.txt` empty) |

The parser does detect malformedness (correct non-zero exit), but the violation text is written to the wrong stream. This violates the project brief requirement for invalid-file reporting and makes automated checking harder, because tools that consume diagnostics from `stderr` receive no errors.

## F-02  RLE size-mismatch files are incorrectly accepted

The BUN specification requires strict consistency between declared and actual uncompressed size when compression is used. Section 5.1(4) states that if the parser detects compressed data and the real expanded size differs from `uncompressed_size`, parsing must abort with `BUN_MALFORMED`.

We tested this using the crafted malformed fixture `tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun`, which contains RLE-compressed data with a deliberately incorrect declared `uncompressed_size`. Reproduction command:

`./target/bun_parser tests/fixtures/invalid/crafted/rle_bad_uncompressed.bun >out.txt 2>err.txt; echo $?`

Run results (also consistent with the Property 2 outcomes in F-04):

| Fixture | Rule violated | Expected exit | Actual exit | Violation emitted |
|---|---|---:|---:|---|
| `rle_bad_uncompressed.bun` | Spec 5.1(4): expanded size must equal `uncompressed_size` | 1 (`BUN_MALFORMED`) | **0 (`BUN_OK`)** | **none** |

The parser prints normal parsed output and returns success, so malformed compressed assets can pass validation. This is a correctness and safety issue: downstream code may trust incorrect metadata and process asset payloads under false size assumptions.

## F-03  `compression == 0` with non-zero `uncompressed_size` is incorrectly accepted

Section 5.1(1) of the BUN spec defines a special-case invariant for uncompressed assets: when `compression == 0` (no compression), `uncompressed_size` must be exactly zero. A non-zero value is malformed.

We validated this rule using `tests/fixtures/invalid/crafted/uncompressed_bad_size.bun`, where the asset is marked uncompressed but sets a non-zero `uncompressed_size`. Reproduction command:

`./target/bun_parser tests/fixtures/invalid/crafted/uncompressed_bad_size.bun >out.txt 2>err.txt; echo $?`

Observed result from reproduction logs:

| Fixture | Rule violated | Expected exit | Actual exit | Violation emitted |
|---|---|---:|---:|---|
| `uncompressed_bad_size.bun` | Spec 5.1(1): for `compression=0`, `uncompressed_size=0` | 1 (`BUN_MALFORMED`) | **0 (`BUN_OK`)** | **none** |

The parser accepts the file as valid and emits no violation text. This bug aligns with the broader property-based failure pattern reported in F-04 (Property 1), where multiple `compression=none + non-zero uncompressed_size` cases were accepted. Together, these results show the invariant is not enforced in the current implementation.

## F-04 Property-based testing

To complement the manually crafted fixtures (each of which only hits one numeric value), we encoded several spec invariants as *properties* and generated a family of inputs that violate each one in different ways. The generator is `tests/generators/bunfile_generator.py`, the driver lives in the `PROPERTY-BASED TESTS` blocks of `tests/scripts/run_all.sh`, and the captured per-input output is `results/property_tests.log`. For each property that we generated a small family of `.bun` files that all violate the same spec rule in different ways, we ran the target parser against each one, and recorded whether it correctly rejected the file (non-zero exit) or incorrectly accepted it (exit 0 or hang). A matching *valid-control* property generates the same shape of file in a spec-conformant way, so that any rejection from the parser is distinguishable from over-eager validation.

We made four properties:

- **Property 1 — If compression is "none", uncompresed_size must be 0** (spec 5.1(1)). We geenrated 7 files with `compression=none` but `uncompressed_size` set to 1, 2, 4, 8, 15, 255, and 9999.

- **Property 2 — For RLE files, the expanded size must match
  uncompressed_size** (spec 5.1(4)). 5 RLE files with wrong declared `uncompressed_size` were generated and the parser should have rejected all 5.
  

- **Property 3 — asset name must stay within the string table**
  (spec 4.2 / 4.3). 5 files with asset names pointing outside an 8-byte string table were generated and the parser sohuld reject all.


- **Property 4 — valid control: `compression == none` with
  `uncompressed_size == 0` must be accepted** (inverse of P1). As a control, 5 completely valid test files were generated as a sanity check to make sure the parser doesn't just reject every file. These 5 files should be accepted by the parser.

Results from one `make reproduce` run on the SDE as logged in `results/property_tests.log`:

| Property | Inputs | Rejected (good) | Accepted (BUG) |
|---|---:|---:|---:|
| P1 — none + nonzero uncompressed_size |  7 | 0 | **7** |
| P2 — RLE size mismatch                |  5 | 0 | **5** |
| P3 — name outside string table        |  5 | 5 | 0 |
| P4 — valid control                    |  5 | 5 (accepted) | 0 false rejections |

As seen from the results above, two of the four properties shows bugs in their parser (P1 and P2). It accepted all 7 broken files from Proeprty 1 when it should have rejected them. The same is seen for Property 2 where all 5 files are accepted even though they should be rejected. The other 2 properties (P3 and P4) work correctly with the former being rejected and the latter shwoing no bugs.

## F-05  Alignment check for `data_section_size` is only run sometimes

The bun spec mentions that all size and offset fields in the header must be a multiple of 4. Four of these fields are checked in `bun_parse.c` at line 165:
```c
if (header->asset_table_offset % 4 != 0 ||
    header->data_section_offset % 4 != 0 ||
    header->string_table_offset % 4 != 0 ||
    header->string_table_size % 4 != 0) {
    bun_add_violation(ctx, "Offsets/sizes must be divisible by 4");
    return BUN_MALFORMED;
```

However, the fifth field is checked separately at line 205 and even then it only checks if the the file's first asset is uncompressed. The check is skipped entirely if the first asset uses RLE or zlib compression and a file with a misaligned `data_section_size` would be accepted.

 ```c
if (header->data_section_size % 4 != 0 && header->asset_count > 0) {
    u64 first_record_pos = header->asset_table_offset;

    if (range_within_file(first_record_pos, (u64)BUN_ASSET_RECORD_SIZE, file_size)) {
      u8 asset_buf[BUN_ASSET_RECORD_SIZE];

      if (fseek(ctx->file, (long)first_record_pos, SEEK_SET) != 0) {
        return BUN_ERR_IO;
      }

      if (fread(asset_buf, 1, BUN_ASSET_RECORD_SIZE, ctx->file) != BUN_ASSET_RECORD_SIZE) {
        return BUN_ERR_IO;
      }

      u32 compression = read_u32_le(asset_buf, 32);

      if (compression == 0) {
        bun_add_violation(ctx, "Uncompressed data section size must be divisible by 4");
        return BUN_MALFORMED;
      }
    }
  }

  return BUN_OK;
}
 ```

Two of our earlier crafted files, `bad_align_single_asset.bun` and `bad_align_multi_asset.bun` were rejected by the parser but only by the earlier check at line 165 because they also misalign other fields as well. It didn't isolate line 205 where we could test a misaligned `data_section_size`. To isolate that, we added `tests/fixtures/invalid/crafted/bad_align_data_section.bun`. The standard generator coudn't create this test therefore, the fixture was built in two steps: `bunfile_generator.py` which produces files that conform to the spec requirement and then `tests/generators/patch_data_section.py` rewrites only `data_section_size` to a non-multiple of 4. All other header fields remain aligned. 

We ran the target parser against the fixture as part of `make reproduce` and recorded the result in `results/crafted_invalid.log` and `results/finding3_summary.log`:

| Fixture | First asset compression | `data_section_size` | Expected exit | Actual exit | Violation emitted |
|---|---|---:|---:|---:|---|
| `bad_align_data_section.bun` | 1 (RLE) | 5 | 1 (`BUN_MALFORMED`) | **0 (`BUN_OK`)** | **none** |

The parser prints the parsed header and asset records as if the file were well-formed and exits `0`. With this fixture the finding is reproducible end-to-end.

## F-06 Compiler-Flag Testing

`tests/scripts/run_sanitized.sh` rebuilds the target parser three ways and re-runs the full reproduction suite against each binary:

| Build | CFLAGS | What it catches |
|---|---|---|
| Strict warnings | `-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -g -O2` | Implicit narrowing, shadowed identifiers, format-string misuse |
| Sanitizer | `-std=c11 -Wall -Wextra -Wpedantic -fsanitize=address,undefined -fno-omit-frame-pointer -g -O2` | Out-of-bounds reads/writes, use-after-free, signed overflow, alignment / shift / bool UB |
| Optimisation | `-std=c11 -Wall -Wextra -Wpedantic -O3 -g0` | Behavioural differences vs. `-O2 -g` (often a tell for undefined behaviour) |

Each build is run against every fixture in the repository — lecturer samples (valid + invalid), crafted (valid + invalid), partial-invalid 01–09, the property-based invalid set and its valid controls, and the alignment-isolation fixture `bad_align_data_section.bun`. Results captured in `results/sanitizer_test_output.log` and `results/optimisation_test_output.log`:

- The strict-warning build compiled with **zero warnings**.
- The sanitizer build reported **no AddressSanitizer, UndefinedBehaviorSanitizer, or LeakSanitizer errors** on any fixture.
- The optimisation build produced the **same exit codes and parser output** as the sanitizer and strict builds on every fixture, so no `-O3`-only behaviour was observed.
