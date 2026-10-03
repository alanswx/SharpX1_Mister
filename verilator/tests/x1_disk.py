"""Read a native X1 system program from a bounded, single-volume D88 image.

This is a debugging/fixture extractor, not a floppy-controller emulator.
The raw result remains subject to the original software's license.
"""
import argparse
import hashlib
import json
import pathlib
import struct


def extract_system(data):
    if len(data) < 688 or struct.unpack_from("<I", data, 28)[0] != len(data):
        raise ValueError("not a complete single-volume D88 image")
    tracks = struct.unpack_from("<164I", data, 32)
    offsets = sorted(set(offset for offset in tracks if offset))
    if not offsets or offsets[0] < 688:
        raise ValueError("invalid track table")
    sectors = []
    for track, offset in enumerate(tracks):
        if not offset:
            continue
        end = next((candidate for candidate in offsets if candidate > offset), len(data))
        cursor = offset
        records = {}
        count = struct.unpack_from("<H", data, cursor + 4)[0]
        if not 1 <= count <= 32:
            raise ValueError("unsupported sector count")
        for _ in range(count):
            if cursor + 16 > end:
                raise ValueError("truncated sector header")
            cylinder, head, number, size_code = data[cursor:cursor + 4]
            size = struct.unpack_from("<H", data, cursor + 14)[0]
            if cylinder != track // 2 or head != track % 2 or number in records:
                raise ValueError("invalid sector geometry")
            if size_code != 1 or size != 256 or cursor + 16 + size > end:
                raise ValueError("expected bounded 256-byte sectors")
            if data[cursor + 8]:
                raise ValueError("sector has a controller error flag")
            records[number] = data[cursor + 16:cursor + 16 + size]
            cursor += 16 + size
        if sorted(records) != list(range(1, count + 1)):
            raise ValueError("missing or non-contiguous sectors")
        sectors.extend(records[number] for number in sorted(records))
    header = sectors[0]
    if header[0] != 1 or header[14:17] != b"Sys":
        raise ValueError("not an X1 system record")
    length, load, entry = struct.unpack_from("<HHH", header, 18)
    start = struct.unpack_from("<H", header, 30)[0]
    required = (length + 255) // 256
    if not length or start + required > len(sectors) or load + length > 65536:
        raise ValueError("system payload exceeds disk/RAM")
    payload = b"".join(sectors[start:start + required])[:length]
    metadata = {"name": header[1:14].decode("ascii", errors="replace").rstrip(),
                "length": length, "load": load, "entry": entry,
                "start_sector": start, "disk_sha256": hashlib.sha256(data).hexdigest(),
                "payload_sha256": hashlib.sha256(payload).hexdigest()}
    return payload, metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    payload, metadata = extract_system(args.disk.read_bytes())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(payload)
    print(json.dumps(metadata, sort_keys=True))
