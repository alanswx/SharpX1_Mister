#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Convert this project's physical Kanji image to an X Millennium FNT1616.X1.

Original code for the SharpX1_Mister reference runner; contains no font data.

Input layouts (see scripts/prepare_kanji.py and scripts/prepare_z_kanji.py):
  half-major (131072 or 262144 bytes, --layout half-major):
      half*65536 + bank*4096 + character*16 + row
  Z chip (262144 bytes, default for boot3.rom, --layout z):
      level*131072 + bank*8192 + character*32 + row*2 + half

X Millennium (font/fontx1.c, x1knjcpy) reads a 306176-byte Shift-JIS ordered
16x16 file: 32 bytes per glyph, row-interleaved left/right bytes, regions
SJIS 8140-84BF at 0x00000, 8890-9FFF at 0x07000, E040-EAAF at 0x35E00.  It
then places each JIS code at its X1 Turbo address
  half*0x20000 + bank*0x1000 + ((jis>>8)&7)*0x200 + (jis&0x1f)*16 + row
with bank = jis2x1t_table[((jis>>9)&0x3c) + ((jis>>5)&3)].  This script
writes the inverse for JIS rows 21..4F (level 1, banks 0..15) only, so that
X Millennium reconstructs the same bank/character/row bytes our core reads.
Level-2 rows (50..77) and unmapped SJIS slots are left zero.

The bank table below is a restatement of the published X1 Turbo JIS row
grouping, used to compute addresses; it is not copied font data.
"""
import argparse
import hashlib
import json
import pathlib
import sys

XMIL_SIZE = 306176
LR = 0x20000

# ((jis >> 9) & 0x3c) + ((jis >> 5) & 3) -> bank, 0xff = unmapped.
BANK = [0xff] * 64
for idx, bank in {0x11: 0x00, 0x12: 0x02, 0x13: 0x01,
                  0x19: 0x04, 0x1a: 0x06, 0x1b: 0x08,
                  0x1d: 0x05, 0x1e: 0x07, 0x1f: 0x09,
                  0x21: 0x0a, 0x22: 0x0c, 0x23: 0x0e,
                  0x25: 0x0b, 0x26: 0x0d, 0x27: 0x0f,
                  0x29: 0x10, 0x2a: 0x12, 0x2b: 0x14,
                  0x2d: 0x11, 0x2e: 0x13, 0x2f: 0x15,
                  0x31: 0x16, 0x32: 0x18, 0x33: 0x1a,
                  0x35: 0x17, 0x36: 0x19, 0x37: 0x1b,
                  0x39: 0x1c, 0x3a: 0x1e, 0x3b: 0x1d}.items():
    BANK[idx] = bank


def x1t_address(jis):
    bank = BANK[((jis >> 9) & 0x3c) + ((jis >> 5) & 3)]
    if bank & 0xc0:
        return None
    return (bank << 12) + ((jis & 0x700) << 1) + ((jis & 0x1f) << 4)


def jis2sjis(jis):
    low = jis & 0x7f
    high = (jis >> 8) & 0x7f
    if not (high & 1):
        low += 0x5e
    if low >= 0x60:
        low += 1
    high = ((high + 0x121) >> 1) ^ 0x20
    return (high << 8) | (low + 0x1f)


def sjis_offset(sjis):
    if 0x8140 <= sjis < 0x84c0:
        return (sjis - 0x8140) << 5
    if 0x8890 <= sjis < 0xa000:
        return 0x07000 + ((sjis - 0x8890) << 5)
    if 0xe040 <= sjis < 0xeab0:
        return 0x35e00 + ((sjis - 0xe040) << 5)
    return None


def half_major_from_z(image):
    out = bytearray(LR * 2)  # X1 Turbo half-major, level-1 banks only.
    for bank in range(16):
        for character in range(256):
            for row in range(16):
                for half in range(2):
                    out[half * LR + bank * 4096 + character * 16 + row] = \
                        image[bank * 8192 + character * 32 + row * 2 + half]
    return bytes(out)


def half_major_from_earlier(image):
    out = bytearray(LR * 2)
    for half in range(2):
        out[half * LR:half * LR + 65536] = image[half * 65536:half * 65536 + 65536]
    return bytes(out)


def xmil_from_half_major(x1t):
    out = bytearray(XMIL_SIZE)
    glyphs = 0
    for high in range(0x21, 0x50):
        for low in range(0x21, 0x7f):
            jis = (high << 8) | low
            dst = sjis_offset(jis2sjis(jis))
            src = x1t_address(jis)
            if dst is None or src is None:
                continue
            for row in range(16):
                out[dst + row * 2] = x1t[src + row]
                out[dst + row * 2 + 1] = x1t[src + LR + row]
            glyphs += 1
    return bytes(out), glyphs


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path,
                        help="new file; an existing file is never overwritten")
    parser.add_argument("--layout", choices=("z", "half-major"), default="z")
    parser.add_argument("--compare", type=pathlib.Path, action="append", default=[],
                        help="existing 306176-byte FNT1616.X1 to compare level-1 glyphs with")
    args = parser.parse_args()
    data = args.source.read_bytes()
    if args.layout == "z":
        if len(data) != 262144:
            sys.exit("z layout needs exactly 262144 bytes")
        x1t = half_major_from_z(data)
    else:
        if len(data) not in (131072, 262144):
            sys.exit("half-major layout needs 131072 or 262144 bytes")
        x1t = half_major_from_earlier(data)
    out, glyphs = xmil_from_half_major(x1t)
    with args.output.open("xb") as handle:
        handle.write(out)
    report = {
        "source": str(args.source), "source_sha256": hashlib.sha256(data).hexdigest(),
        "layout": args.layout, "output": str(args.output),
        "output_sha256": hashlib.sha256(out).hexdigest(), "bytes": len(out),
        "level1_glyphs_written": glyphs, "level2": "zero (not present in source)",
        "comparisons": [],
    }
    for other in args.compare:
        ref = other.read_bytes()
        same = differ = 0
        for high in range(0x21, 0x50):
            for low in range(0x21, 0x7f):
                jis = (high << 8) | low
                dst = sjis_offset(jis2sjis(jis))
                if dst is None or x1t_address(jis) is None:
                    continue
                if ref[dst:dst + 32] == out[dst:dst + 32]:
                    same += 1
                else:
                    differ += 1
        report["comparisons"].append({"file": str(other),
                                      "sha256": hashlib.sha256(ref).hexdigest(),
                                      "level1_glyphs_equal": same,
                                      "level1_glyphs_different": differ})
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
