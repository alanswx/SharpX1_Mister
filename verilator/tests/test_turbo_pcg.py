"""Original CPU I/O fixtures: provisional Turbo PCG and CPU ANK16 contract.

No private ROM/game/font bytes. Supply an isolated non-savable Turbo runner.
"""
import argparse
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program

parser = argparse.ArgumentParser()
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--timeout", type=float, default=180)
args = parser.parse_args()
cells = (0x7FF, 0x3FF, 0x5FF, 0x1FF)


def fixture(loaded):
    p = Program()

    def output(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def equal(port, value):
        p.store(0xF002, port & 255)
        p.store(0xF003, port >> 8)
        p.store(0xF004, value)
        p.word(0x01, port)
        p.emit(0xED, 0x78)
        p.word(0x32, 0xF001)  # Keep exact failed actual/port/expected in JSON peek.
        p.emit(0xFE, value)
        p.jump(0xC2, "fail")

    def configure():
        output(0x1A03, 0x82)
        equal(0x1A02, 0)  # Clears reset-time DAM, no private IPL needed.
        output(0x1A02, 0x40)
        # Recurrent HSYNC in either ordinary or X3 clock profile.
        for register, value in enumerate((15, 1, 2, 0x12, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)):
            output(0x1800, register)
            output(0x1801, value)

    def font_byte(glyph, row):
        address = glyph * 16 + row
        return (address ^ (address >> 8) ^ 0xA6) & 255 if loaded else 0

    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "warm")
    configure()
    output(0x1FD0, 0x20)
    equal(0x1400, 255)  # Explicit unknown metadata, not fabricated power-up glyph.
    for i, cell in enumerate(cells):
        output(0x3000 + cell, 65 + i)
        equal(0x3000 + cell, 65 + i)
        output(0x3800 + cell, 0)
        equal(0x3800 + cell, 0)
    for mask in range(16):
        for i, cell in enumerate(cells):
            # 2xxx attribute aliases must update the same shadow entry.
            output(0x2800 + cell, (32 if mask & (1 << i) else 0) | (i * 3))
            equal(0x2800 + cell, (32 if mask & (1 << i) else 0) | (i * 3))
        chosen = next((i for i in range(4) if mask & (1 << i)), 0)
        for plane in range(1, 4):
            port = 0x1400 + plane * 256
            value = (mask + plane * 31) & 255
            output(port, value)
            equal(port | 0xF1, value)  # nibble 0/1 and high nibble aliases
        # Independent ROM selector, FONT16 in BOTH scan-rate settings.
        rom_cell = next((i for i in range(4) if not mask & (1 << i)), 0)
        for scan in (0, 1):
            output(0x1FD0, 0x60 | scan)
            for row in (0, 1, 7, 8, 15):
                equal(0x14F0 + row, font_byte(65 + rom_cell, row))
        output(0x1FD0, 0x20)
    # PCG fallback with every attribute clear; paired even/odd glyph aliases.
    for cell in cells:
        output(0x2000 + cell, 0)
    for kan in (0, 0x10, 0x80, 0x90):
        # Text and Kanji metadata use distinct halves of 3xxx.
        output(0x37FF, 0xFF)
        output(0x3FFF, kan)
        for plane in range(1, 4):
            port = 0x1400 + plane * 256
            for row in range(16 if kan else 8):
                output(port + (row if kan else row * 2), (plane * 53 + row) & 255)
            for row in range(16):
                equal(port + row, (plane * 53 + (row if kan else row // 2)) & 255)
        if kan:
            output(0x37FF, 0xFE)
            equal(0x150F, 68)  # Same pair as FF; row15 = 53+15.
    output(0x37FF, 65)
    output(0x3FFF, 0x10)  # b4 alone does not dispatch Kanji.
    output(0x1FD0, 0x60)
    equal(0x140F, font_byte(65, 15))
    output(0x140F, 255)
    equal(0x140F, font_byte(65, 15))  # CPU cannot mutate ANK16.
    output(0x1FD0, 0x20)
    equal(0x1400, 0x18)  # Existing ANK8 A, row0; distinct from generated ANK16.
    equal(0x14F1, 0x18)
    output(0x14F0, 0)
    equal(0x1400, 0x18)
    for kan in (0x80, 0x90, 0xC0):
        output(0x3FFF, kan)
        for scrn in (0x20, 0x60, 0x61):
            output(0x1FD0, scrn)
            equal(0x1400, 255)
            equal(0x140F, 255)
    output(0x3FFF, 0)
    output(0x1FD0, 0x60)
    p.store(0xF040, 0xA5)
    for i, value in enumerate(b"PCG!"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("warm")
    configure()
    output(0x1FD0, 0x60)
    # No text/attribute/KVRAM/font reload: retained shadow agrees with VRAM.
    equal(0x140F, font_byte(65, 15))
    for i, value in enumerate(b"WARM"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    result = p.finish()
    assert len(result) <= 32768
    return result


with tempfile.TemporaryDirectory(prefix="x1-turbo-pcg-cpu-") as temp:
    folder = pathlib.Path(temp)
    font = folder / "original-font.bin"
    font.write_bytes(bytes((a ^ (a >> 8) ^ 0xA6) & 255 for a in range(4096)))
    for loaded in (False, True):
        rom = folder / f"pcg-{loaded}.bin"
        rom.write_bytes(fixture(loaded))
        for warm in (False, True):
            command = [str(args.executable.resolve()), "--cycles", "1600000", "--rom", str(rom)]
            if loaded:
                command += ["--font16", str(font)]
            if warm:
                command += ["--reset-at", "25", "--reset-for-us", "10"]
            result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=args.timeout)
            report = json.loads(result.stdout.splitlines()[-1])
            expected = b"WARM" if warm else b"PCG!"
            if not (report["halted"] and report["peek"].startswith(expected.hex())):
                print(result.stdout, flush=True)
                raise AssertionError(report)
            print(json.dumps({"loaded": loaded, "warm": warm, "sys_hz": report["sys_hz"],
                              "video_hz": report["video_hz"], "peek": report["peek"][:8]}), flush=True)
print("PASS: CPU selected PCG/paired/mirrors, ANK8/16 scan-independent/read-only, FF Kanji, retained warm reset")
