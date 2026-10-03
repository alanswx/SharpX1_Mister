"""Original CPU fixture: PPI mode 0/BSR and both PSG joystick inputs."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program


def fixture(joya, joyb):
    p = Program()
    p.emit(0xF3)

    def output(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def equal(port, value, mask=255):
        p.word(0x01, port)
        p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        p.jump(0xC2, "fail")

    # Reset: all ports inputs. Ignore unprogrammed video and mailbox phase.
    equal(0x1A00, 255)
    equal(0x1A02, 255)
    equal(0x1A01, 1, 0x1B)  # IPL on, no printer/tape input, BREAK inactive.
    output(0x1A03, 0x82)  # A/C outputs, B input.
    equal(0x1A00, 0)
    equal(0x1A02, 0)  # Reads also clear reset-time DAM.
    output(0x1A00, 0xA5)
    equal(0x1A00, 0xA5)
    output(0x1A02, 0xD5)  # Keep PC5 low: do not enter DAM.
    equal(0x1A02, 0xD5)
    output(0x1A03, 0x02)  # BSR reset PC1.
    equal(0x1A02, 0xD5)
    output(0x1A03, 0x03)  # BSR set PC1, leaving direction/mode intact.
    equal(0x1A02, 0xD7)
    output(0x1A03, 0x0C)  # BSR reset PC6 (80-column selector).
    equal(0x1A02, 0x97)
    # Mode changes clear output latches; lower/upper C input independently.
    output(0x1A03, 0x83)
    equal(0x1A02, 0x0F)
    output(0x1A03, 0x8A)
    equal(0x1A02, 0xF0)
    output(0x1A03, 0x82)
    equal(0x1A02, 0)
    # Each PSG register uses mirrored address/data ports.
    masks = (255, 15, 255, 15, 255, 15, 31, 255, 31, 31, 31, 255, 255, 15)
    for register, mask in enumerate(masks):
        output(0x1C5A, register)
        output(0x1B99, 0xA5)
        equal(0x1BFF, 0xA5 & mask)
    output(0x1C5A, 7)
    output(0x1B99, 0x3F)
    for register, value in ((14, joya), (15, joyb)):
        output(0x1CFF, register)
        output(0x1B00, 0)  # Input-mode pins must not be overwritten by the latch.
        equal(0x1B01, value)
    for i, value in enumerate(b"PORT"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-ports-") as folder:
    rom = pathlib.Path(folder) / "ports.bin"
    for joya, joyb in ((255, 255), (0xDE, 0xB7), (0xBF, 0xFD)):
        rom.write_bytes(fixture(joya, joyb))
        result = subprocess.run([exe, "--cycles", "100000", "--rom", str(rom),
                                 "--joya", str(joya), "--joyb", str(joyb)],
                                check=True, capture_output=True, text=True)
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["halted"] and report["peek"].startswith(b"PORT".hex()), report
    for flag in ("--joya", "--joyb"):
        for invalid in ("256", "-1", "bad"):
            assert subprocess.run([exe, flag, invalid], capture_output=True).returncode == 2
print("PASS: PPI mode-0 directions/latches/BSR/reset and both PSG joystick ports")
