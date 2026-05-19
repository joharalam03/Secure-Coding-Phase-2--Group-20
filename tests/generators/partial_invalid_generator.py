#!/usr/bin/env python3

"""
Generate partially-invalid BUN fixtures.

These files are intentionally malformed but still contain some recoverable
assets so parsers can test:

- violation accumulation
- partial recovery
- continued parsing after corruption
- bounds checking
- malformed string tables
- malformed asset records
"""

from pathlib import Path
import struct
import sys

# ------------------------------------------------------------
# Constants
# ------------------------------------------------------------

BUN_MAGIC = 0x304E5542
BUN_VERSION_MAJOR = 1
BUN_VERSION_MINOR = 0

_HEADER_FMT = "<IHHIQQQQQQ"
_RECORD_FMT = "<IIQQQIIII"

HEADER_SIZE = struct.calcsize(_HEADER_FMT)
RECORD_SIZE = struct.calcsize(_RECORD_FMT)

COMPRESS_NONE = 0

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

def align4(x: int) -> int:
    return (x + 3) & ~3


def write_padding(f, n: int) -> None:
    if n > 0:
        f.write(b"\x00" * n)


def write_header(
    f,
    *,
    asset_count,
    asset_table_offset,
    string_table_offset,
    string_table_size,
    data_section_offset,
    data_section_size,
    magic=BUN_MAGIC,
    version_major=BUN_VERSION_MAJOR,
    version_minor=BUN_VERSION_MINOR,
    reserved=0,
):
    f.write(struct.pack(
        _HEADER_FMT,
        magic,
        version_major,
        version_minor,
        asset_count,
        asset_table_offset,
        string_table_offset,
        string_table_size,
        data_section_offset,
        data_section_size,
        reserved,
    ))


def write_asset_record(
    f,
    *,
    name_offset,
    name_length,
    data_offset,
    data_size,
    uncompressed_size=0,
    compression=COMPRESS_NONE,
    asset_type=0,
    checksum=0,
    flags=0,
):
    f.write(struct.pack(
        _RECORD_FMT,
        name_offset,
        name_length,
        data_offset,
        data_size,
        uncompressed_size,
        compression,
        asset_type,
        checksum,
        flags,
    ))


# ------------------------------------------------------------
# Generic Fixture Builder
# ------------------------------------------------------------

def build_fixture(
    out_path: Path,
    assets,
    *,
    truncate_string_bytes=0,
):
    """
    Build a BUN fixture from asset definitions.

    Each asset dict may contain:
      name
      payload
      name_offset
      name_length
      data_offset
      data_size
      compression
      checksum
      flags
    """

    out_path.parent.mkdir(parents=True, exist_ok=True)

    asset_count = len(assets)

    # --------------------------------------------------------
    # Compute layout
    # --------------------------------------------------------

    asset_table_offset = align4(HEADER_SIZE)

    string_table_offset = align4(
        asset_table_offset + asset_count * RECORD_SIZE
    )

    full_string_table = b"".join(
        asset["name"] for asset in assets
    )

    if truncate_string_bytes > 0:
        string_table = full_string_table[:-truncate_string_bytes]
    else:
        string_table = full_string_table

    string_table_size = align4(len(string_table))

    data_section = b"".join(
        asset["payload"] for asset in assets
    )

    data_section_offset = align4(
        string_table_offset + string_table_size
    )

    data_section_size = align4(len(data_section))

    # --------------------------------------------------------
    # Write file
    # --------------------------------------------------------

    with open(out_path, "wb") as f:

        # Header
        write_header(
            f,
            asset_count=asset_count,
            asset_table_offset=asset_table_offset,
            string_table_offset=string_table_offset,
            string_table_size=string_table_size,
            data_section_offset=data_section_offset,
            data_section_size=data_section_size,
        )

        # Header padding
        write_padding(
            f,
            asset_table_offset - HEADER_SIZE
        )

        # ----------------------------------------------------
        # Asset records
        # ----------------------------------------------------

        name_cursor = 0
        data_cursor = 0

        for asset in assets:

            write_asset_record(
                f,

                name_offset=asset.get(
                    "name_offset",
                    name_cursor,
                ),

                name_length=asset.get(
                    "name_length",
                    len(asset["name"]),
                ),

                data_offset=asset.get(
                    "data_offset",
                    data_cursor,
                ),

                data_size=asset.get(
                    "data_size",
                    len(asset["payload"]),
                ),

                uncompressed_size=asset.get(
                    "uncompressed_size",
                    0,
                ),

                compression=asset.get(
                    "compression",
                    COMPRESS_NONE,
                ),

                asset_type=asset.get(
                    "asset_type",
                    0,
                ),

                checksum=asset.get(
                    "checksum",
                    0,
                ),

                flags=asset.get(
                    "flags",
                    0,
                ),
            )

            name_cursor += len(asset["name"])
            data_cursor += len(asset["payload"])

        # ----------------------------------------------------
        # Padding before string table
        # ----------------------------------------------------

        current_pos = (
            asset_table_offset +
            asset_count * RECORD_SIZE
        )

        write_padding(
            f,
            string_table_offset - current_pos
        )

        # ----------------------------------------------------
        # String table
        # ----------------------------------------------------

        f.write(string_table)

        write_padding(
            f,
            string_table_size - len(string_table)
        )

        # ----------------------------------------------------
        # Data section
        # ----------------------------------------------------

        f.write(data_section)

        write_padding(
            f,
            data_section_size - len(data_section)
        )

    print(f"Wrote {out_path}")


# ------------------------------------------------------------
# Partial Invalid Fixture Suite
# ------------------------------------------------------------

def make_partial_invalid_suite():

    base = Path(
        "tests/fixtures/invalid/crafted"
    )

    # --------------------------------------------------------
    # Original partial string attack
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_01_partial_string_attack.bun",

        [
            {
                "name": b"GOOD",
                "payload": b"AAAA",
            },

            {
                "name": b"BAD",
                "payload": b"BBBB",
                "name_offset": 100,
            },

            {
                "name": b"TRUNC",
                "payload": b"CCCC",
            },
        ],

        truncate_string_bytes=1,
    )

    # --------------------------------------------------------
    # Truncated final asset name
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_02_truncated_last_name.bun",

        [
            {
                "name": b"GOOD1",
                "payload": b"AAAA",
            },

            {
                "name": b"GOOD2",
                "payload": b"BBBB",
            },

            {
                "name": b"TRUNCATED",
                "payload": b"CCCC",
            },
        ],

        truncate_string_bytes=3,
    )

    # --------------------------------------------------------
    # Out-of-bounds name offset
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_03_oob_name_offset.bun",

        [
            {
                "name": b"VISIBLE",
                "payload": b"AAAA",
            },

            {
                "name": b"BROKEN",
                "payload": b"BBBB",
                "name_offset": 999999,
            },

            {
                "name": b"VISIBLE2",
                "payload": b"CCCC",
            },
        ],
    )

    # --------------------------------------------------------
    # Invalid name length
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_04_invalid_name_length.bun",

        [
            {
                "name": b"GOOD",
                "payload": b"AAAA",
            },

            {
                "name": b"SHORT",
                "payload": b"BBBB",
                "name_length": 9999,
            },

            {
                "name": b"GOOD2",
                "payload": b"CCCC",
            },
        ],
    )

    # --------------------------------------------------------
    # Invalid data offset
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_05_invalid_data_offset.bun",

        [
            {
                "name": b"GOOD",
                "payload": b"AAAA",
            },

            {
                "name": b"BAD",
                "payload": b"BBBB",
                "data_offset": 999999,
            },

            {
                "name": b"GOOD2",
                "payload": b"CCCC",
            },
        ],
    )

    # --------------------------------------------------------
    # Multiple simultaneous violations
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_06_multi_violation.bun",

        [
            {
                "name": b"OK1",
                "payload": b"AAAA",
            },

            {
                "name": b"BAD1",
                "payload": b"BBBB",
                "name_offset": 99999,
            },

            {
                "name": b"BAD2",
                "payload": b"CCCC",
                "name_length": 5000,
            },

            {
                "name": b"BAD3",
                "payload": b"DDDD",
                "data_offset": 88888,
            },

            {
                "name": b"OK2",
                "payload": b"EEEE",
            },
        ],

        truncate_string_bytes=2,
    )

    # --------------------------------------------------------
    # Middle asset partially truncated
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_07_middle_name_cutoff.bun",

        [
            {
                "name": b"FIRST",
                "payload": b"AAAA",
            },

            {
                "name": b"MIDDLEBROKEN",
                "payload": b"BBBB",
            },

            {
                "name": b"LAST",
                "payload": b"CCCC",
            },
        ],

        truncate_string_bytes=8,
    )

    # --------------------------------------------------------
    # Multiple recoverable assets after corruption
    # --------------------------------------------------------

    build_fixture(
        base / "partial_invalid_08_recover_after_bad_asset.bun",

        [
            {
                "name": b"GOOD_A",
                "payload": b"1111",
            },

            {
                "name": b"BAD_A",
                "payload": b"2222",
                "name_offset": 777777,
            },

            {
                "name": b"GOOD_B",
                "payload": b"3333",
            },

            {
                "name": b"GOOD_C",
                "payload": b"4444",
            },
        ],
    )

    build_fixture(
        base / "partial_invalid_09_violation_accumulation.bun",
        [
            {
                "name": b"GOOD_A",
                "payload": b"1111",
            },

            # violation #1: bad name offset
            {
                "name": b"BAD_A",
                "payload": b"2222",
                "name_offset": 999999,
            },

            # violation #2: bad data offset
            {
                "name": b"GOOD_B",
                "payload": b"3333",
                "data_offset": 888888,
            },

            # violation #3: bad name length
            {
                "name": b"BAD_C",
                "payload": b"4444",
                "name_length": 50000,
            },

            # should still be readable if parser continues
            {
                "name": b"GOOD_D",
                "payload": b"5555",
            },
        ],
    )


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

def main():

    make_partial_invalid_suite()

    print("\nDone generating partial-invalid fixtures.")


if __name__ == "__main__":
    sys.exit(main())