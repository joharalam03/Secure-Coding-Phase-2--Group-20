#!/usr/bin/env python3
from pathlib import Path
import struct
import sys

BUN_MAGIC = 0x304E5542
BUN_VERSION_MAJOR = 1
BUN_VERSION_MINOR = 0
_HEADER_FMT = "<IHHIQQQQQQ"
_RECORD_FMT = "<IIQQQIIII"

HEADER_SIZE = struct.calcsize(_HEADER_FMT)
RECORD_SIZE = struct.calcsize(_RECORD_FMT)

def align4(x):
    return (x + 3) & ~3

def write_header(f, **kwargs):
    f.write(struct.pack(
        _HEADER_FMT,
        kwargs.get("magic", BUN_MAGIC),
        kwargs.get("version_major", BUN_VERSION_MAJOR),
        kwargs.get("version_minor", BUN_VERSION_MINOR),
        kwargs["asset_count"],
        kwargs["asset_table_offset"],
        kwargs["string_table_offset"],
        kwargs["string_table_size"],
        kwargs["data_section_offset"],
        kwargs["data_section_size"],
        kwargs.get("reserved", 0),
    ))

def write_asset_record(f, **kwargs):
    f.write(struct.pack(
        _RECORD_FMT,
        kwargs["name_offset"],
        kwargs["name_length"],
        kwargs["data_offset"],
        kwargs["data_size"],
        kwargs.get("uncompressed_size", 0),
        kwargs.get("compression", 0),
        kwargs.get("asset_type", 0),
        kwargs.get("checksum", 0),
        kwargs.get("flags", 0),
    ))

def write_padding(f, n):
    if n > 0:
        f.write(b"\x00" * n)

def main():
    out_path = Path("tests/fixtures/invalid/crafted/partial-string-attack.bun")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # -------------------
    # Assets
    # -------------------
    assets = [
        # Asset 0: valid
        {"name": b"GOOD", "payload": b"AAAA", "compression": 0},
        # Asset 1: name_offset out of bounds (points past string table)
        {"name": b"BAD", "payload": b"BBBB", "compression": 0, "name_offset": 100},
        # Asset 2: partially truncated name in string table
        {"name": b"TRUNC", "payload": b"CCCC", "compression": 0},
    ]

    asset_count = len(assets)

    # -------------------
    # Compute offsets
    # -------------------
    asset_table_offset = align4(HEADER_SIZE)
    string_table_offset = align4(asset_table_offset + asset_count * RECORD_SIZE)

    # Build full string table
    string_table_data = b"".join(a["name"] for a in assets)
    
    # Truncate **internally** to simulate corruption but keep header size aligned
    string_table_truncated = string_table_data[:-1]  # remove last byte of last asset
    string_table_size = align4(len(string_table_truncated))  # must be divisible by 4

    data_section_offset = align4(string_table_offset + string_table_size)
    data_section_data = b"".join(a["payload"] for a in assets)
    data_section_size = align4(len(data_section_data))

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

        # Padding to asset table
        write_padding(f, asset_table_offset - HEADER_SIZE)

        # Write asset records
        offset_accum = 0
        for idx, a in enumerate(assets):
            name_offset = a.get("name_offset", offset_accum)
            name_length = len(a["name"])
            data_offset = sum(len(x["payload"]) for x in assets[:idx])
            data_size = len(a["payload"])

            write_asset_record(
                f,
                name_offset=name_offset,
                name_length=name_length,
                data_offset=data_offset,
                data_size=data_size,
                compression=a.get("compression", 0)
            )

            offset_accum += len(a["name"])

        # Padding before string table
        write_padding(f, string_table_offset - (asset_table_offset + asset_count * RECORD_SIZE))

        # Write truncated string table and pad to aligned size
        f.write(string_table_truncated)
        write_padding(f, string_table_size - len(string_table_truncated))

        # Write data section
        f.write(data_section_data)
        write_padding(f, data_section_size - len(data_section_data))

    print(f"Wrote {out_path} (string table attack: partial/truncated + out-of-bounds)")

if __name__ == "__main__":
    sys.exit(main())