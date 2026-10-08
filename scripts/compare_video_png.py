#!/usr/bin/env python3
"""Exact native RGB8 MiSTer PNG versus P6 simulation reference comparison.

No rescaling, crop, color tolerance or image rewriting. Unsupported PNG formats
are rejected; this is deliberately narrower than a general image decoder.
"""
import argparse
import json
import pathlib
import struct
import zlib


def rgb_png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    offset, compressed, dimensions = 8, bytearray(), None
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset+4:offset+8]
        payload = data[offset+8:offset+8+length]
        crc = struct.unpack_from(">I", data, offset+8+length)[0]
        assert zlib.crc32(kind+payload) == crc, "PNG CRC"
        offset += length+12
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            assert (depth, color, compression, filtering, interlace) == (8, 2, 0, 0, 0)
            assert 0 < width <= 4096 and 0 < height <= 4096
            dimensions = width, height
        if kind == b"IDAT":
            compressed.extend(payload)
        if kind == b"IEND":
            break
    assert dimensions
    width, height = dimensions
    raw = zlib.decompress(compressed)
    stride = width*3
    assert len(raw) == (stride+1)*height
    result, previous = bytearray(), bytearray(stride)
    for y in range(height):
        start = y*(stride+1)
        mode = raw[start]
        assert mode <= 4
        row = bytearray(raw[start+1:start+1+stride])
        for i in range(stride):
            left = row[i-3] if i >= 3 else 0
            above = previous[i]
            diagonal = previous[i-3] if i >= 3 else 0
            if mode == 4:
                prediction = left+above-diagonal
                distances = (abs(prediction-left), abs(prediction-above), abs(prediction-diagonal))
                predictor = (left, above, diagonal)[distances.index(min(distances))]
            else:
                predictor = (0, left, above, (left+above)//2)[mode]
            row[i] = (row[i]+predictor)&255
        result.extend(row)
        previous = row
    return dimensions, bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("png", type=pathlib.Path)
    parser.add_argument("ppm", type=pathlib.Path)
    args = parser.parse_args()
    dimensions, actual = rgb_png(args.png)
    header, size, maximum, expected = args.ppm.read_bytes().split(b"\n", 3)
    assert header == b"P6" and maximum == b"255"
    assert dimensions == tuple(map(int, size.split())), (dimensions, size)
    assert len(actual) == len(expected)
    mismatches = sum(actual[i:i+3] != expected[i:i+3] for i in range(0, len(actual), 3))
    print(json.dumps({"png": str(args.png), "ppm": str(args.ppm), "dimensions": dimensions,
                      "checked_pixels": len(actual)//3, "mismatching_pixels": mismatches}))
    assert mismatches == 0, "Hardware RGB differs from reference"


if __name__ == "__main__":
    main()
