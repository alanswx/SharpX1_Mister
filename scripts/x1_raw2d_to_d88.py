"""Wrap standard 320 KiB X1 .2d sector bytes in a protected D88 container.

Original implementation; geometry/order references (local MAME checkout):
src/lib/formats/2d_dsk.cpp: _2d_format::formats
src/lib/formats/wd177x_dsk.cpp: get_image_offset/build_sector_description
src/lib/formats/d88_dsk.cpp: container header and track-order documentation

Only 40 cylinders, two heads, 16 ascending sector IDs (1..16), 256 bytes,
MFM are supported. Raw media cannot retain deleted marks, CRC errors, physical
gaps or protection timing; ordinary clean sector metadata is synthesized.
Payloads, boot records and loader bytes are never patched. Conversion is not
proof of native IPL boot, gameplay, or redistribution permission.
"""

import argparse
import hashlib
import json
import pathlib
import struct

RAW_BYTES = 40 * 2 * 16 * 256


def raw2d_to_d88(raw, label="X1 raw 2D"):
    """Return one protected 348848-byte volume; reject any other geometry."""
    if len(raw) != RAW_BYTES:
        raise ValueError("expected exactly 327680 bytes for standard X1 raw .2d")
    name = label.encode("ascii")
    if not name or len(name) > 16 or b"\0" in name:
        raise ValueError("label must be 1..16 non-NUL ASCII bytes")
    image = bytearray(688)
    image[:len(name)] = name
    image[26] = 0x10  # Protected; all testing writes must use disposable copies.
    image[27] = 0x00  # 2D.
    for cylinder in range(40):
        for head in range(2):
            track = cylinder * 2 + head
            struct.pack_into("<I", image, 32 + track * 4, len(image))
            for sector in range(1, 17):
                header = bytearray(16)
                header[:4] = bytes((cylinder, head, sector, 1))
                struct.pack_into("<H", header, 4, 16)
                # density/deleted/status and reserved fields remain zero (MFM).
                struct.pack_into("<H", header, 14, 256)
                offset = ((cylinder * 2 + head) * 16 + sector - 1) * 256
                image.extend(header)
                image.extend(raw[offset:offset + 256])
    struct.pack_into("<I", image, 28, len(image))
    return bytes(image)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--label", default="X1 raw 2D")
    args = parser.parse_args()
    with args.source.open("rb") as source:
        raw = source.read(RAW_BYTES + 1)
    image = raw2d_to_d88(raw, args.label)
    # Explicit new destination; never overwrite an original or existing copy.
    with args.output.open("xb") as output:
        output.write(image)
    print(json.dumps({"source": str(args.source.resolve()),
                      "source_bytes": len(raw),
                      "source_sha256": hashlib.sha256(raw).hexdigest(),
                      "output": str(args.output.resolve()),
                      "output_bytes": len(image),
                      "output_sha256": hashlib.sha256(image).hexdigest(),
                      "geometry": "40 cylinders/2 heads/16 sectors/256 bytes; C,H,R order",
                      "conversion": "container only; clean MFM metadata synthesized",
                      "protected": True}, indent=2))


if __name__ == "__main__":
    main()
