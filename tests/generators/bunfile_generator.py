#!/usr/bin/env python3
"""
BUN file generator (parameterized).

Usage examples:
  # Minimal valid bun
  python3 bunfile_generator.py --out minimal.bun

  # Reserved field non-zero (for testing false rejection)
  python3 bunfile_generator.py --reserved 1 --out reserved_nonzero.bun

  # Single asset with RLE compression
  python3 bunfile_generator.py --compression rle --asset-payload "AAAABBBB" --out rle_test.bun
"""

import struct
import sys
import argparse
from pathlib import Path

# Constants
BUN_MAGIC = 0x304E5542
BUN_VERSION_MAJOR = 1
BUN_VERSION_MINOR = 0
COMPRESS_MAP = {"none": 0, "rle": 1, "zlib": 2}

# On-disk format
_HEADER_FMT = "<IHHIQQQQQQ"
_RECORD_FMT = "<IIQQQIIII"
HEADER_SIZE = struct.calcsize(_HEADER_FMT)
RECORD_SIZE = struct.calcsize(_RECORD_FMT)

def _align4(n: int) -> int:
    return (n + 3) & ~3

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
    parser = argparse.ArgumentParser(description="BUN file generator")
    parser.add_argument("--out", required=True, help="Output .bun file path")
    parser.add_argument("--reserved", type=int, default=0, help="Reserved header field")
    parser.add_argument("--asset-name", default="hello", help="Asset name")
    parser.add_argument("--asset-payload", default="Hello, BUN!", help="Asset payload")
    parser.add_argument("--compression", default="none", choices=COMPRESS_MAP.keys())
    parser.add_argument("--uncompressed-size", type=int, default=0, help="Fake uncompressed size for testing RLE mismatch")
    args = parser.parse_args()

    asset_name = args.asset_name.encode()
    asset_payload = args.asset_payload.encode()
    compression = COMPRESS_MAP[args.compression]

    asset_count = 1
    asset_table_offset = _align4(HEADER_SIZE)
    string_table_offset = _align4(asset_table_offset + asset_count * RECORD_SIZE)
    string_table_size = _align4(len(asset_name))
    data_section_offset = _align4(string_table_offset + len(asset_name))
    data_section_size = _align4(len(asset_payload))

    out_path = Path(args.out)
    with open(out_path, "wb") as f:
        # Header
        write_header(f,
                     asset_count=asset_count,
                     asset_table_offset=asset_table_offset,
                     string_table_offset=string_table_offset,
                     string_table_size=string_table_size,
                     data_section_offset=data_section_offset,
                     data_section_size=data_section_size,
                     reserved=args.reserved)

        # Header padding
        write_padding(f, asset_table_offset - HEADER_SIZE)
        # Asset record
        write_asset_record(f,
                           name_offset=0,
                           name_length=len(asset_name),
                           data_offset=0,
                           data_size=len(asset_payload),
                           compression=compression,
                           uncompressed_size=args.uncompressed_size)
        # Records padding
        write_padding(f, string_table_offset - (asset_table_offset + RECORD_SIZE))
        # String table
        f.write(asset_name)
        write_padding(f, string_table_size - len(asset_name))
        # Data section
        write_padding(f, data_section_offset - (string_table_offset + string_table_size))
        f.write(asset_payload)
        write_padding(f, data_section_size - len(asset_payload))

    print(f"Wrote {out_path} ({out_path.stat().st_size} bytes)")

if __name__ == "__main__":
    sys.exit(main())