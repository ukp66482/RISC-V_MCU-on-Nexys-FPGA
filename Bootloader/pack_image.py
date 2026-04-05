#!/usr/bin/env python3
"""
pack_image.py

Prepends a 16-byte boot header to a raw application binary.

Header format (little-endian):
  [0:3]   magic      = 0xDEADBEEF
  [4:7]   app_size   = length of app binary (bytes)
  [8:11]  entry_addr = entry point address (default: 0x60000000)
  [12:15] crc32      = CRC32 of app binary

Usage:
  python3 pack_image.py app.bin app_packed.bin
  python3 pack_image.py app.bin app_packed.bin --entry 0x60000000
"""

import struct
import sys
import zlib
import argparse

BOOT_MAGIC = 0xDEADBEEF

def main():
    parser = argparse.ArgumentParser(description="Pack app binary with boot header")
    parser.add_argument("input",  help="Input raw binary file (app.bin)")
    parser.add_argument("output", help="Output packed binary file (app_packed.bin)")
    parser.add_argument("--entry", default="0x60000000",
                        help="Entry point address (default: 0x60000000)")
    args = parser.parse_args()

    entry_addr = int(args.entry, 0)

    with open(args.input, "rb") as f:
        app_data = f.read()

    app_size = len(app_data)
    app_crc  = zlib.crc32(app_data) & 0xFFFFFFFF

    # Pack header: magic, size, entry, crc32 (all little-endian uint32)
    header = struct.pack("<IIII", BOOT_MAGIC, app_size, entry_addr, app_crc)

    with open(args.output, "wb") as f:
        f.write(header)
        f.write(app_data)

    print(f"Input:      {args.input}")
    print(f"App size:   {app_size} bytes (0x{app_size:08X})")
    print(f"Entry addr: 0x{entry_addr:08X}")
    print(f"CRC32:      0x{app_crc:08X}")
    print(f"Output:     {args.output} ({app_size + 16} bytes total)")

if __name__ == "__main__":
    main()
