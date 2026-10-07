# SPDX-License-Identifier: GPL-2.0-only
"""Asset-free exhaustive conversion checks; no private/member bytes bundled."""
import importlib.util
import pathlib
import subprocess
import sys
import tempfile

source = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "prepare_kanji.py"
spec = importlib.util.spec_from_file_location("prepare_kanji", source)
converter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)
members = {f"kanji{n}.rom": bytes((a * 37 + (a >> 8) * 13 + n * 71) & 255
                                for a in range(32768)) for n in range(1, 5)}
physical = converter.physical_from_members(members)
assert len(physical) == 131072
# Independent forward interleave into display glyph/half/row space, using
# MAME's audited raw-region order rather than converter's physical order.
raw = b"".join(members[f"kanji{n}.rom"] for n in (4, 2, 3, 1))
display = bytearray(131072)
seen = bytearray(131072)
for base in (0, 65536):
    for raw_offset in range(65536):
        cell = raw_offset % 32768
        display_offset = base + (cell // 16) * 32 + (raw_offset // 32768) * 16 + cell % 16
        assert not seen[display_offset]
        seen[display_offset] = 1
        display[display_offset] = raw[base + raw_offset]
assert all(seen)
for half in range(2):
    for bank in range(16):
        for glyph in range(256):
            for row in range(16):
                address = half * 65536 + bank * 4096 + glyph * 16 + row
                display_address = ((bank * 256 + glyph) * 2 + half) * 16 + row
                assert physical[address] == display[display_address], address
for bad in ({}, {**members, "unexpected": b""}, {**members, "kanji1.rom": b"short"}):
    try:
        converter.physical_from_members(bad)
    except ValueError:
        pass
    else:
        raise AssertionError("invalid shape accepted")
try:
    converter.verify_members(members)
except ValueError as error:
    assert "unqualified" in str(error)
else:
    raise AssertionError("synthetic members passed native identity checks")
with tempfile.TemporaryDirectory(prefix="x1-conversion-cli-") as directory:
    root = pathlib.Path(directory)
    archive, destination = root / "invalid.7z", root / "must-not-exist"
    archive.write_bytes(b"original invalid archive fixture")
    result = subprocess.run([sys.executable, str(source), str(archive), "--source-format",
                             "audited-model40-raw", "--output-dir", str(destination)],
                            capture_output=True, text=True, timeout=10)
    assert result.returncode != 0 and "unqualified archive hash" in result.stderr
    assert not destination.exists()
    result = subprocess.run([sys.executable, str(source), str(archive), "--output-dir", str(destination)],
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 2 and "--source-format" in result.stderr
    assert not destination.exists()
print("PASS: 131072 conversion bytes, independent forward display interleave, bijection, shape/hash rejection")
