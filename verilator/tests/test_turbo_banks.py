"""Original CPU bus diagnostic for the opt-in Turbo foundation (no BIOS)."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program(0x8000)
p.emit(0xF3)
p.word(0x3A, 0xF000)
p.emit(0xFE, ord("T"))
p.jump(0xCA, "warm")
def out(port, value):
    p.word(0x01, port)
    p.emit(0x3E, value, 0xED, 0x79)
def equal(port, value):
    p.word(0x01, port)
    p.emit(0xED, 0x78, 0xFE, value)
    p.jump(0xC2, "fail")

out(0x1A03, 0x82)
p.word(0x01, 0x1A02)
p.emit(0xED, 0x78)  # Clear DAM induced by PPI direction initialization.
for bank in range(2):
    out(0x1FDF, bank << 4)  # All sixteen SCRN addresses are write aliases.
    for plane, start in enumerate((0x4000, 0x8000, 0xC000)):
        for offset in (0, 1, 0x1FFF, 0x3FFE, 0x3FFF):
            out(start + offset, 0x31 + plane * 7 + bank * 0x40 + (offset & 3))
for display in range(2):
    for bank in range(2):
        out(0x1FD0, (bank << 4) | (display << 3))
        for plane, start in enumerate((0x4000, 0x8000, 0xC000)):
            for offset in (0, 1, 0x1FFF, 0x3FFE, 0x3FFF):
                equal(start + offset, 0x31 + plane * 7 + bank * 0x40 + (offset & 3))
for alias in range(16):
    out(0x1FD0 + alias, (alias & 1) << 4)
    equal(0x4000, 0x31 + (alias & 1) * 0x40)
for offset in (0, 1, 0x3FF, 0x7FF):
    out(0x3000 + offset, 0x5A)
    out(0x3800 + offset, 0xA5)
    equal(0x3000 + offset, 0x5A)
    equal(0x3800 + offset, 0xA5)
equal(0x1FD0, 0xFF)  # Do not implement Turbo Z readable SCRN on Turbo.
out(0x1FE0, 0xFF)
equal(0x1FE0, 0xFF)  # Blackclip is also write-only on the original Turbo.
for bank in range(2):
    out(0x1FD0, bank << 4)
    for start in (0x4000, 0x8000, 0xC000): out(start + 0x1FD0, 0xA0 + bank)
out(0x1FD0, 0x10)
out(0x1A02, 0x20)
out(0x1A02, 0)  # DAM owns the following apparent SCRN write.
out(0x1FD0, 0)
for start in (0x4000, 0x8000, 0xC000): equal(start + 0x1FD0, 0)
out(0x1FD0, 0)
for start in (0x4000, 0x8000, 0xC000): equal(start + 0x1FD0, 0xA0)
out(0x1FD0, 0x18)  # Leave nonzero access/display pages for warm reset.
out(0x1FE0, 0x7F)
for i, value in enumerate(b"TRB!"): p.store(0xF000+i, value)
p.emit(0x76)
p.label("warm")
# IPL/bootstrap resets selectors, not video storage. Do not reinitialize it.
for plane, start in enumerate((0x4000, 0x8000, 0xC000)):
    equal(start, 0x31 + plane * 7)
    equal(start + 0x1FD0, 0xA0)
out(0x1FD0, 0x10)
for plane, start in enumerate((0x4000, 0x8000, 0xC000)):
    equal(start, 0x71 + plane * 7)
    equal(start + 0x1FD0, 0)
equal(0x3000, 0x5A)
equal(0x3800, 0xA5)
for i, value in enumerate(b"RST!"): p.store(0xF004+i, value)
p.emit(0x76)
p.label("fail")
p.store(0xF000, 0xEE)
p.emit(0x76)
with tempfile.TemporaryDirectory(prefix="x1-turbo-banks-") as folder:
    rom = pathlib.Path(folder) / "banks.bin"
    rom.write_bytes(p.finish())
    for reset_args, expected in (([], b"TRB!"), (["--reset-at", "20", "--reset-for-us", "10"], b"TRB!RST!")):
        result = subprocess.run([str(pathlib.Path(sys.argv[1]).resolve()), "--cycles", "1000000",
                                 "--ram", str(rom), *reset_args], capture_output=True, text=True, check=True)
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["halted"] and report["peek"].startswith(expected.hex()), report
        print(json.dumps(report))
print("PASS: Turbo CPU/display bank selection, planes/boundaries, DAM isolation, separate text/Kanji VRAM, write-only ports, warm-reset selectors and retained video RAM")
