"""Base profile keeps experimental CTC ports unmapped (original CPU fixture)."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program()
p.emit(0xF3)
for port in range(0x1FA0, 0x1FB0):
    p.word(0x01, port)
    p.emit(0x3E, 0xD7, 0xED, 0x79, 0x3E, 0x01, 0xED, 0x79)
    p.emit(0xED, 0x78, 0xFE, 0xFF)
    p.jump(0xC2, "fail")
for index, value in enumerate(b"BASE"):
    p.store(0xF000 + index, value)
p.emit(0x76)
p.label("fail")
p.store(0xF000, 0xEE)
p.emit(0x76)
with tempfile.TemporaryDirectory(prefix="x1-ctc-base-") as directory:
    rom = pathlib.Path(directory) / "base.bin"
    rom.write_bytes(p.finish())
    result = subprocess.run([str(pathlib.Path(sys.argv[1]).resolve()), "--cycles", "200000",
                             "--rom", str(rom)], check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert not report["turbo_foundation"], report
    assert report["halted"] and report["peek"].startswith(b"BASE".hex()), report
print("PASS: base model keeps CTC and adjacent unmapped ports at FF after writes")
