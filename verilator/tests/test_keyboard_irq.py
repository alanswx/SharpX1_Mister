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
# Preserve every two-byte response, not just the first and last interrupt.
# HL = F100 + 2*event_count; ISR saves/restores the main program's registers.
p.word(0x3A, 0xF000)
p.emit(0x87, 0x6F, 0x26, 0xF1)
for index in range(2):
    p.word(0x3A, 0xF010 + index)
    p.emit(0x77, 0x23)
p.word(0x3A, 0xF000)
p.emit(0x3C)
p.word(0x32, 0xF000)
p.emit(0xE1, 0xC1, 0xF1, 0xFB, 0xED, 0x4D)

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-irq-") as folder:
    ram = pathlib.Path(folder) / "irq.bin"
    ram.write_bytes(p.finish())
    script = pathlib.Path(folder) / "keys.txt"
    cases = (
        # Exact cold fixture: do not move I outside command turnaround.
        ("cold", "25 2b\n45 f0\n47 2b\n60 43\n80 f0\n82 43\n100 3b\n120 f0\n122 3b\n",
         ("b746", "f700", "b749", "f700", "b74a", "f700")),
        # Retain the existing steady-state fixture in addition to the cold one.
        ("steady", "25 2b\n45 f0\n47 2b\n100 43\n120 f0\n122 43\n175 3b\n195 f0\n197 3b\n",
         ("b746", "f700", "b749", "f700", "b74a", "f700")),
        # The inherited last-key policy ignores releases of older held keys.
        ("overlap", "25 2b\n60 43\n80 f0\n82 2b\n100 3b\n120 f0\n122 43\n140 f0\n142 3b\n",
         ("b746", "b749", "b74a", "f700")),
    )
    for name, keys, expected in cases:
        script.write_text(keys)
        dump = pathlib.Path(folder) / name
        result = subprocess.run([exe, "--cycles", "8000000", "--ram", str(ram),
                                 "--keys", str(script), "--dump", str(dump)],
                                check=True, capture_output=True, text=True, timeout=180)
        report = json.loads(result.stdout.splitlines()[-1])
        memory = dump.with_suffix(".ram").read_bytes()
        assert report["ps2_bytes_sent"] == len(keys.splitlines()), report
        assert memory[0xF000] == len(expected), (
            name, memory[0xF000], memory[0xF100:0xF110].hex(), report)
        assert memory[0xF021] == 0x46, (name, memory[0xF020:0xF022].hex(), report)
        assert memory[0xF011] == 0, (name, memory[0xF010:0xF012].hex(), report)
        events = [memory[0xF100 + 2*i:0xF102 + 2*i] for i in range(len(expected))]
        assert events == [bytes.fromhex(value) for value in expected], (
            name, [event.hex() for event in events], report)
        print(f"PASS: {name} IM 1 responses", " ".join(event.hex() for event in events), flush=True)
print("PASS: cold/steady/overlapping make/break ordering, modifier/ASCII bytes and RETI return")
