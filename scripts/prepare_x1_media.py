"""Stage user-supplied ZIP D88/D77 media as private, hashed simulation fixtures.

Never overwrite originals, trust archive paths, or infer redistribution rights.
Writes are exclusive; existing matching fixture copies may be reused.
"""
import argparse
import hashlib
import json
import pathlib
import re
import struct
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("archive", type=pathlib.Path)
parser.add_argument("--output", type=pathlib.Path,
                    default=pathlib.Path("references/software/private-downloads/commercial"))
args = parser.parse_args()
source = args.archive.resolve()
original = source.read_bytes()
archive_hash = hashlib.sha256(original).hexdigest()
slug = re.sub(r"[^a-z0-9]+", "-", source.stem.lower()).strip("-")[:80]
folder = args.output.resolve() / (slug + "-" + archive_hash[:12])
records = []
with zipfile.ZipFile(source) as archive:
    candidates = [item for item in archive.infolist()
                  if pathlib.PurePosixPath(item.filename).suffix.lower() in (".d88", ".d77")]
    candidates += [item for item in archive.infolist()
                   if pathlib.PurePosixPath(item.filename).suffix.lower() == ".2d"]
    if not candidates:
        raise ValueError("archive has no D88/D77 fixture; raw/tape conversion is not implied")
    for index, item in enumerate(candidates):
        if not 688 <= item.file_size <= 1048575:
            raise ValueError("fixture exceeds current image aperture or lacks a header")
        data = archive.read(item)  # zipfile verifies CRC, bounded by member size above.
        member_hash = hashlib.sha256(data).hexdigest()
        conversion = "none"
        if pathlib.PurePosixPath(item.filename).suffix.lower() == ".2d":
            # Original container-only conversion. MAME 2d_dsk.cpp specifies
            # 40 cylinders, 2 sides, 16 sectors, 256 bytes; wd177x_dsk.cpp
            # stores (cylinder * heads + side) * track_size.
            if len(data) != 327680: raise ValueError("unsupported raw 2D geometry")
            wrapped = bytearray(688)
            wrapped[:16] = b"X1 PRIVATE TEST\0"
            for track in range(80):
                struct.pack_into("<I", wrapped, 32 + 4 * track, len(wrapped))
                for sector in range(16):
                    header = bytearray(16)
                    header[:4] = bytes((track // 2, track % 2, sector + 1, 1))
                    struct.pack_into("<H", header, 4, 16)
                    struct.pack_into("<H", header, 14, 256)
                    offset = (track * 16 + sector) * 256
                    wrapped.extend(header + data[offset:offset + 256])
            struct.pack_into("<I", wrapped, 28, len(wrapped))
            data = bytes(wrapped)
            conversion = "raw 40x2x16x256 sector bytes wrapped in D88, no payload changes"
        digest = hashlib.sha256(data).hexdigest()
        # No archive-provided path is used for writing.
        target = folder / f"disk-{index}-{digest[:12]}.d88"
        folder.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if target.read_bytes() != data: raise ValueError("existing fixture differs")
        else:
            with target.open("xb") as output: output.write(data)
        records.append({"member": item.filename, "member_sha256": member_hash,
                        "conversion": conversion, "bytes": len(data), "sha256": digest,
                        "image": str(target)})
if source.read_bytes() != original:
    raise ValueError("archive changed during staging; wait for download completion")
manifest = {"archive": str(source), "archive_sha256": archive_hash,
            "provenance": "User-supplied local testing collection; redistribution permission not inferred",
            "records": records}
metadata = folder / "manifest.json"
if not metadata.exists():
    with metadata.open("x") as output: json.dump(manifest, output, indent=2)
print(json.dumps(manifest, indent=2))
