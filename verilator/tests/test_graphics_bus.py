"""Original Z80 diagnostic for GRAM planes and DAM peripheral isolation."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program()
p.emit(0xF3)
p.word(0x31, 0xFFFF)


def output(port, value):
    p.word(0x01, port)
    p.emit(0x3E, value, 0xED, 0x79)


def read_equal(port, value):
    p.word(0x01, port)
    p.emit(0xED, 0x78, 0xFE, value)
    p.jump(0xC2, "fail")


def dam():
    output(0x1A02, 0x20)
    output(0x1A02, 0)


output(0x1A03, 0x82)
p.word(0x01, 0x1A02)
p.emit(0xED, 0x78)  # Clear any reset-time DAM transition.
output(0x1E00, 0)
p.store(0, 0xA5)
for port, value in ((0x4005, 0xAA), (0x8005, 0xBB), (0xC005, 0xCC)):
    output(port, value)
    read_equal(port, value)
for address, data, planes in (
        (0x0005, 0xDD, (0xDD, 0xDD, 0xDD)),
        (0x4005, 0xEE, (0xDD, 0xEE, 0xEE)),
        (0x8005, 0xFF, (0xFF, 0xEE, 0xFF)),
        (0xC005, 0x99, (0x99, 0x99, 0xFF))):
    dam()
    output(address, data)
    for port, value in zip((0x4005, 0x8005, 0xC005), planes):
        read_equal(port, value)
# A graphics write whose low 14 bits alias the ROM-enable port must not
# enable IPL or send a host command while DAM owns the I/O address space.
dam()
output(0x1D00, 0x55)
output(0x1900, 0x77)
for offset, value in ((0x1D00, 0x55), (0x1900, 0x77)):
    for base in (0x4000, 0x8000, 0xC000):
        read_equal(base + offset, value)
p.compare_memory(0, 0xA5)
for index, value in enumerate(b"GRAM"):
    p.store(0xF000 + index, value)
p.emit(0x76)
p.label("fail")
p.store(0xF000, 0xEE)
p.emit(0x76)

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-gram-") as folder:
    rom = pathlib.Path(folder) / "gram.bin"
    rom.write_bytes(p.finish())
    result = subprocess.run([exe, "--cycles", "1000000", "--rom", str(rom),
                             "--ram", str(rom), "--load-address", "0"],
                            check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["peek"].startswith(b"GRAM".hex()), report
print("PASS: individual GRAM planes, DAM masks/read-clear, peripheral aliases and IPL isolation")
