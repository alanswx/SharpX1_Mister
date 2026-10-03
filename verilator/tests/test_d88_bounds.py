"""Original generated D88 preflight cases; no external ROM/media assets."""
import pathlib
import struct
import subprocess
import sys
import tempfile

exe = str(pathlib.Path(sys.argv[1]).resolve())


def volume():
    image = bytearray(688)
    for track in range(2):
        struct.pack_into("<I", image, 32 + track * 4, len(image))
        for sector in range(2):
            header = bytearray(16)
            header[:4] = bytes((0, track, sector + 1, sector))
            struct.pack_into("<H", header, 4, 2)
            struct.pack_into("<H", header, 14, 128 << sector)
            image.extend(header + bytes([sector + 1]) * (128 << sector))
    struct.pack_into("<I", image, 28, len(image))
    return image


def changed(offset, value, fmt="<I"):
    image = volume()
    struct.pack_into(fmt, image, offset, value)
    return image


cases = [
    ("mixed sizes", volume(), None),
    ("concatenated volumes", volume() + volume(), None),
    ("short header", volume()[:687], "invalid D88: truncated volume header"),
    ("bad volume size", changed(28, 687), "invalid D88: volume size"),
    ("truncated volume", volume()[:-1], "invalid D88: volume size"),
    ("offset into header", changed(32, 687), "invalid D88: track offset"),
    ("offset past end", changed(32, len(volume())), "invalid D88: track offset"),
    ("offset high bits", changed(32, 0x100000), "invalid D88: track offset"),
    ("overlapping offsets", changed(36, 688), "unsupported D88: non-increasing"),
    ("zero sector count", changed(688 + 4, 0, "<H"), "invalid D88: zero sector count"),
    ("oversized sector count", changed(688 + 4, 256, "<H"), "unsupported D88: sector count"),
    ("inconsistent count", changed(688 + 144 + 4, 1, "<H"), "invalid D88: inconsistent"),
    ("payload crosses track", changed(688 + 14, 65535, "<H"), "invalid D88: sector payload"),
    ("unsupported size code", changed(688 + 3, 4, "B"), "unsupported D88: sector length"),
    ("length disagrees with N", changed(688 + 14, 127, "<H"), "unsupported D88: sector length"),
    ("trailing partial volume", volume() + b"truncated", "invalid D88: truncated volume header"),
]
# Track boundary cuts the second record's header rather than its payload.
cases.append(("truncated sector header", changed(36, 688 + 144 + 8),
              "invalid D88: truncated sector header"))
short_first = changed(32, len(volume()) - 8)
struct.pack_into("<I", short_first, 36, 0)
cases.append(("truncated first sector header", short_first,
              "invalid D88: truncated first sector header"))
with tempfile.TemporaryDirectory(prefix="x1-d88-bounds-") as temporary:
    for index, (label, data, error) in enumerate(cases):
        source = pathlib.Path(temporary) / f"case{index}.d88"
        source.write_bytes(data)
        before = source.read_bytes()
        result = subprocess.run([exe, "--cycles", "2000", "--disk", str(source)],
                                capture_output=True, text=True, timeout=20)
        if error:
            assert result.returncode != 0 and error in result.stderr, (label, result.stdout, result.stderr)
        else:
            assert result.returncode == 0, (label, result.stderr)
        assert source.read_bytes() == before, label
print(f"PASS: {len(cases)} D88 preflight cases; bounded headers/tracks/payloads, unsupported layouts, unchanged sources")
