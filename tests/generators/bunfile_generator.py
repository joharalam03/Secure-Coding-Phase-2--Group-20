#!/usr/bin/env python3
"""
BUN file generator (parameterized + property-based fuzzing).

Existing usage still works.

NEW:
  --mode fuzz --count N  → generates multiple randomized files
"""

import struct
import sys
import argparse
from pathlib import Path
import random

# Constants
BUN_MAGIC = 0x304E5542
BUN_VERSION_MAJOR = 1
BUN_VERSION_MINOR = 0
COMPRESS_MAP = {"none": 0, "rle": 1, "zlib": 2}

_HEADER_FMT = "<IHHIQQQQQQ"
_RECORD_FMT = "<IIQQQIIII"

HEADER_SIZE = struct.calcsize(_HEADER_FMT)
RECORD_SIZE = struct.calcsize(_RECORD_FMT)


# =========================
# helpers
# =========================

def align4(x):
    return (x + 3) & ~3


def write_padding(f, n):
    if n > 0:
        f.write(b"\x00" * n)


def random_string():
    length = random.randint(1, 16)
    return ''.join(random.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ") for _ in range(length))


def random_payload():
    size = random.randint(1, 64)
    return bytes(random.getrandbits(8) for _ in range(size))


# =========================
# writers
# =========================

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


# =========================
# core generator (single)
# =========================

def generate_single(args):
    asset_name = args.asset_name.encode()
    asset_payload = args.asset_payload.encode()
    compression = COMPRESS_MAP[args.compression]
    asset_count = args.asset_count

    asset_table_offset = HEADER_SIZE
    if not args.force_misalignment:
        asset_table_offset = align4(asset_table_offset)

    string_table_offset = asset_table_offset + asset_count * RECORD_SIZE
    if not args.force_misalignment:
        string_table_offset = align4(string_table_offset)

    string_table_size = len(asset_name)
    if not args.force_misalignment:
        string_table_size = align4(string_table_size)

    data_section_offset = string_table_offset + string_table_size
    if not args.force_misalignment:
        data_section_offset = align4(data_section_offset)

    data_section_size = len(asset_payload)
    if not args.force_misalignment:
        data_section_size = align4(data_section_size)

    out_path = Path(args.out)

    with open(out_path, "wb") as f:

        write_header(
            f,
            asset_count=asset_count,
            asset_table_offset=asset_table_offset,
            string_table_offset=string_table_offset,
            string_table_size=string_table_size,
            data_section_offset=data_section_offset,
            data_section_size=data_section_size,
            reserved=args.reserved,
        )

        write_padding(f, asset_table_offset - HEADER_SIZE)

        for _ in range(asset_count):
            write_asset_record(
                f,
                name_offset=0,
                name_length=len(asset_name),
                data_offset=0,
                data_size=len(asset_payload),
                compression=compression,
                uncompressed_size=args.uncompressed_size,
            )

        write_padding(f, string_table_offset - (asset_table_offset + asset_count * RECORD_SIZE))

        f.write(asset_name)
        write_padding(f, string_table_size - len(asset_name))

        write_padding(f, data_section_offset - (string_table_offset + string_table_size))

        f.write(asset_payload)
        write_padding(f, data_section_size - len(asset_payload))

    print(f"Wrote {out_path}")


# =========================
# main
# =========================

def main():
    parser = argparse.ArgumentParser(description="BUN file generator")

    parser.add_argument("--out", required=True)
    parser.add_argument("--reserved", type=int, default=0)
    parser.add_argument("--asset-name", default="hello")
    parser.add_argument("--asset-payload", default="Hello, BUN!")
    parser.add_argument("--compression", default="none", choices=COMPRESS_MAP.keys())
    parser.add_argument("--uncompressed-size", type=int, default=0)
    parser.add_argument("--asset-count", type=int, default=1)
    parser.add_argument("--force-misalignment", action="store_true")

    # NEW PBT CONTROLS
    parser.add_argument("--mode", default="single", choices=["single", "fuzz", "property-none-size"])
    parser.add_argument("--count", type=int, default=1)

    args = parser.parse_args()

    # =========================
    # PROPERTY-BASED FUZZ MODE
    # =========================
    if args.mode == "fuzz":
        base_out = args.out

        for i in range(args.count):
            args.asset_name = random_string()
            args.asset_payload = random_payload().decode(errors="ignore")

            # mutate properties (intentional violations)
            args.reserved = random.choice([0, 0, 0, 1, 9999])
            args.asset_count = random.randint(1, 5)
            args.force_misalignment = random.choice([False, True])
            args.compression = random.choice(list(COMPRESS_MAP.keys()))

            args.out = str(Path(base_out).with_name(f"{Path(base_out).stem}_{i}.bun"))

            generate_single(args)

        return

    if args.mode == "property-none-size":
        base_out = Path(args.out)
        base_out.parent.mkdir(parents=True, exist_ok=True)

        bad_sizes = [1, 2, 4, 8, 15, 255, 9999]

        for size in bad_sizes:
            args.asset_name = "hello"
            args.asset_payload = "Hello, BUN!"
            args.compression = "none"
            args.uncompressed_size = size
            args.asset_count = 1
            args.reserved = 0
            args.force_misalignment = False

            args.out = str(
                base_out.with_name(f"{base_out.stem}_{size}.bun")
            )

            generate_single(args)

        return

    # =========================
    # NORMAL MODE
    # =========================
    generate_single(args)


if __name__ == "__main__":
    sys.exit(main())