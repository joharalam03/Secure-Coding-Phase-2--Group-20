import struct, sys

path = sys.argv[1]

DATA_SECTION_SIZE_OFFSET = 44  # header offset for data_section_size

with open(path, "r+b") as f:
    # read current data_section_size
    f.seek(DATA_SECTION_SIZE_OFFSET)
    orig = f.read(8)
    size = struct.unpack("<Q", orig)[0]
    size += 1  # misalign
    f.seek(DATA_SECTION_SIZE_OFFSET)
    f.write(struct.pack("<Q", size))

    # read data_section_offset from header
    f.seek(36)
    data_section_offset_bytes = f.read(8)
    data_section_offset = struct.unpack("<Q", data_section_offset_bytes)[0]

    # pad file to match new data_section_size
    f.seek(0, 2)  # go to EOF
    eof = f.tell()
    pad_needed = size - (eof - data_section_offset)
    if pad_needed > 0:
        f.write(b"\x00" * pad_needed)

print("Patched data_section_size to misaligned and padded file")