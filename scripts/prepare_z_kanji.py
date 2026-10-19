#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original Z physical (index-5) Kanji image from the audited model-40 set.

Reuses prepare_kanji.py's pinned archive/member authentication and its
half-major model-20/30 layout, then permutes bytes into the CZ-880 sheet-46
pin order (docs/TURBO_Z_KANJI_STORAGE_STATUS.md):

  earlier: half*65536 + bank*4096 + character*16 + row   (x1_kanji_address)
  Z chip : bank*8192  + character*32 + row*2 + half      (x1_z_kanji_address)

Both decoders name the same DKAN3..0 bank, DCHA7..0 character and K4Y..K1Y
row nets, so this is a pure permutation of level-1 glyphs. The model-40 set
has no second level: IC66 (bytes 131072..262143) is filled with FILL. No ROM
data is embedded here; outputs are private and must not be committed.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import prepare_kanji  # noqa: E402

LEVEL_BYTES = 131072
FILL = 0x00


def z_level_from_half_major(earlier):
    if len(earlier) != LEVEL_BYTES:
        raise ValueError("earlier physical image must contain exactly 131072 bytes")
    out = bytearray(LEVEL_BYTES)
    for bank in range(16):
        for character in range(256):
            for row in range(16):
                for half in range(2):
                    out[bank * 8192 + character * 32 + row * 2 + half] = \
                        earlier[half * 65536 + bank * 4096 + character * 16 + row]
    return bytes(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=pathlib.Path)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True,
                        help="new private directory; existing targets are never overwritten")
    args = parser.parse_args()
    if args.archive.stat().st_size > 1048576:
        raise ValueError("unqualified archive size")
    archive_bytes = args.archive.read_bytes()
    archive_hash = hashlib.sha256(archive_bytes).hexdigest()
    if archive_hash != prepare_kanji.ARCHIVE_SHA256:
        raise ValueError("unqualified archive hash; only the audited model-40 source is accepted")
    members = {}
    with tempfile.TemporaryDirectory(prefix="x1-z-kanji-conversion-") as directory:
        frozen = pathlib.Path(directory) / "source.7z"
        frozen.write_bytes(archive_bytes)
        for name in prepare_kanji.PHYSICAL_ORDER:
            result = subprocess.run(["7z", "x", "-so", str(frozen), name],
                                    capture_output=True, check=True, timeout=30)
            members[name] = result.stdout
    prepare_kanji.verify_members(members)
    earlier = prepare_kanji.physical_from_members(members)
    level1 = z_level_from_half_major(earlier)
    image = level1 + bytes([FILL]) * LEVEL_BYTES
    # Independent spot check of the permutation against the member files.
    order = prepare_kanji.PHYSICAL_ORDER
    for bank, character, row, half in ((0, 0, 0, 0), (3, 0x41, 7, 1), (15, 255, 15, 1), (8, 0x80, 9, 0)):
        chip = (half << 1) | (bank >> 3)
        member = members[order[chip]]
        expected = member[(bank & 7) * 4096 + character * 16 + row]
        if image[bank * 8192 + character * 32 + row * 2 + half] != expected:
            raise AssertionError("permutation spot check failed")
    digest = hashlib.sha256(image).hexdigest()
    metadata = {
        "archive_sha256": archive_hash, "member_sha1": prepare_kanji.MEMBER_SHA1,
        "earlier_layout": "half*65536 + bank*4096 + character*16 + row",
        "z_layout": "level*131072 + bank*8192 + character*32 + row*2 + half",
        "level2_fill": FILL, "earlier_sha256": hashlib.sha256(earlier).hexdigest(),
        "bytes": len(image), "sha256": digest,
        "qualification": "net-name permutation of the model-40 level-1 set; no level-2 glyphs; "
                         "not native CZ-880 ROM bytes",
        "provenance": "user-supplied local archive; private output, no redistribution permission inferred",
    }
    args.output_dir.mkdir(parents=True, exist_ok=False)
    with (args.output_dir / "z-kanji-physical.bin").open("xb") as destination:
        destination.write(image)
    with (args.output_dir / "provenance.json").open("x") as destination:
        json.dump(metadata, destination, indent=2)
        destination.write("\n")
    print(json.dumps({"path": str(args.output_dir / "z-kanji-physical.bin"), "sha256": digest,
                      "bytes": len(image)}))


if __name__ == "__main__":
    main()
