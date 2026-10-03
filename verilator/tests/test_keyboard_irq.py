"""Check native firmware keyboard interrupt byte ordering in Z80 IM 1."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program(0x8000)
p.emit(0xF3)
p.word(0x31, 0xFFFF)
p.store(0xF000, 0)
for address, value in ((0x38, 0xC3), (0x39, 0x00), (0x3A, 0x82)):
    p.store(address, value)
p.word(0x01, 0x1A03)
p.emit(0x3E, 0x82, 0xED, 0x79)
for index, value in enumerate((0xE4, 0x52)):
    p.word(0x01, 0x1A01)
    p.label(f"tx{index}")
    p.emit(0xED, 0x78, 0xE6, 0x40)
    p.jump(0xC2, f"tx{index}")
    p.word(0x01, 0x1900)
    p.emit(0x3E, value, 0xED, 0x79)
p.emit(0xED, 0x56, 0xFB)  # IM 1; EI
p.label("loop")
p.emit(0)
p.jump(0xC3, "loop")
p.code.extend(bytes(0x200 - len(p.code)))
p.emit(0xF5, 0xC5, 0xE5)  # ISR at 8200
for index in range(2):
    p.word(0x01, 0x1A01)
    p.label(f"rx{index}")
    p.emit(0xED, 0x78, 0xE6, 0x20)
    p.jump(0xC2, f"rx{index}")
    p.word(0x01, 0x1900)
    p.emit(0xED, 0x78)
    p.word(0x32, 0xF010 + index)
p.word(0x3A, 0xF000)
p.emit(0xB7)
p.jump(0xC2, "count")
for index in range(2):
    p.word(0x3A, 0xF010 + index)
    p.word(0x32, 0xF020 + index)
p.label("count")
p.word(0x3A, 0xF000)
p.emit(0x3C)
p.word(0x32, 0xF000)
p.emit(0xE1, 0xC1, 0xF1, 0xFB, 0xED, 0x4D)

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-irq-") as folder:
    ram = pathlib.Path(folder) / "irq.bin"
    ram.write_bytes(p.finish())
    script = pathlib.Path(folder) / "keys.txt"
    script.write_text("25 2b\n45 f0\n47 2b\n")
    dump = pathlib.Path(folder) / "irq"
    result = subprocess.run([exe, "--cycles", "3000000", "--ram", str(ram),
                             "--keys", str(script), "--dump", str(dump)],
                            check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    memory = dump.with_suffix(".ram").read_bytes()
    assert memory[0xF000] == 2, (memory[0xF000], report)
    assert memory[0xF021] == 0x46, (memory[0xF020:0xF022].hex(), report)
    assert memory[0xF011] == 0, (memory[0xF010:0xF012].hex(), report)
    print("IRQ make", memory[0xF020:0xF022].hex(), "break", memory[0xF010:0xF012].hex())
print("PASS: IM 1 interrupt acknowledge, modifier/ASCII ordering, make/break and RETI return")
