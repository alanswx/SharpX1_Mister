"""Exercise MR16 firmware host handshakes using original Z80 instructions."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

p = Program()
p.emit(0xF3)
p.word(0x31, 0xFFFF)
# PPI mode 0, port B input, other ports output.
p.word(0x01, 0x1A03)
p.emit(0x3E, 0x82, 0xED, 0x79)
for i, byte in enumerate((0xE7, 0x04, 0xE8)):
    p.word(0x01, 0x1A01)
    p.label(f"ready{i}")
    p.emit(0xED, 0x78, 0xE6, 0x40)
    p.jump(0xC2, f"ready{i}")
    p.word(0x01, 0x1900)
    p.emit(0x3E, byte, 0xED, 0x79)
p.word(0x01, 0x1A01)
p.label("reply")
p.emit(0xED, 0x78, 0xE6, 0x20)
p.jump(0xC2, "reply")
p.word(0x01, 0x1900)
p.emit(0xED, 0x78)
p.word(0x32, 0xF000)
p.emit(0x76)

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-subcpu-") as folder:
    rom = pathlib.Path(folder) / "host.bin"
    rom.write_bytes(p.finish())
    result = subprocess.run([exe, "--cycles", "1000000", "--rom", str(rom)],
                            check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["peek"].startswith("04"), report
    # Receive a real set-2 key packet through the firmware's PS/2 interrupt.
    key = Program()
    key.emit(0xF3)
    key.word(0x31, 0xFFFF)
    key.word(0x01, 0x1A03)
    key.emit(0x3E, 0x82, 0xED, 0x79)
    key.label("poll")
    key.word(0x01, 0x1A01)
    key.label("tx")
    key.emit(0xED, 0x78, 0xE6, 0x40)
    key.jump(0xC2, "tx")
    key.word(0x01, 0x1900)
    key.emit(0x3E, 0xE6, 0xED, 0x79)
    for index in range(2):
        key.word(0x01, 0x1A01)
        key.label(f"rx{index}")
        key.emit(0xED, 0x78, 0xE6, 0x20)
        key.jump(0xC2, f"rx{index}")
        key.word(0x01, 0x1900)
        key.emit(0xED, 0x78)
        key.word(0x32, 0xF000 + index)
    key.emit(0xFE, 0x46)  # CAPS defaults on: set-2 2B translates to 'F'.
    key.jump(0xC2, "poll")
    key.emit(0x76)
    rom.write_bytes(key.finish())
    script = pathlib.Path(folder) / "key.txt"
    script.write_text("25 2b\n45 f0\n47 2b\n")
    result = subprocess.run([exe, "--cycles", "3000000", "--rom", str(rom),
                             "--keys", str(script)], check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["peek"][2:4] == "46", report
print("PASS: native MR16 firmware E7 parameter/E8 reply, PPI TX/RX handshakes")
print("PASS: PS/2 set-2 make packet translated to ASCII by native MR16 firmware")
