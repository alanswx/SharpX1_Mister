"""Original shared-machine CPU/INI physical Kanji fixture; no private assets."""
import argparse
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program


def pattern(address):
    return (address * 37 + (address >> 8) * 13 + (address >> 16) * 211 + 19) & 255


def fixture(loaded):
    p = Program()

    def output(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def equal(port, value):
        p.word(0x01, port)
        p.emit(0xED, 0x78)
        p.word(0x32, 0xF001)
        p.emit(0xFE, value)
        p.jump(0xC2, "fail")

    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    output(0x1A03, 0x82)
    equal(0x1A02, 0)  # Clear reset-time DAM using the native PPI read.
    output(0x1A02, 0x40)
    for register, value in enumerate((15, 1, 2, 0x12, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)):
        output(0x1800, register)
        output(0x1801, value)
    output(0x1FD0, 0x60)
    for cell in (0x7FF, 0x3FF, 0x5FF, 0x1FF):
        output(0x2000 + cell, 7)
        output(0x3000 + cell, 0)
        output(0x3800 + cell, 0)
    for half in range(2):
        for bank in range(16):
            for glyph in (0, 255):
                output(0x3FFF, 0x80 | (half << 6) | bank)
                output(0x37FF, glyph)
                p.word(0x01, 0x1400)
                p.word(0x21, 0xD000)
                for row in range(16):
                    # Native block-I/O shape: preserve B after INI decrements
                    # it; advance C to the next CG row. Results are CPU RAM.
                    p.emit(0xED, 0xA2, 0x04, 0x0C)
                for row in range(16):
                    address = (half << 16) | (bank << 12) | (glyph << 4) | row
                    p.compare_memory(0xD000 + row, pattern(address) if loaded else 255)
    output(0x3FFF, 0xCF)
    equal(0x140F, pattern(0x1FFFF) if loaded else 255)
    output(0x140F, 0)  # First-level ROM is read-only.
    equal(0x140F, pattern(0x1FFFF) if loaded else 255)
    output(0x3FFF, 0xDF)  # Absent level 2 must not alias first-level bytes.
    equal(0x140F, 255)
    output(0x3FFF, 0)
    output(0x37FF, 65)
    output(0x1FD0, 0x20)
    equal(0x1400, 0x18)  # ANK route still independent of Kanji ROM.
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "warm")
    p.store(0xF040, 0xA5)
    for i, value in enumerate(b"KAN!"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("warm")
    for i, value in enumerate(b"WARM"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    result = p.finish()
    assert len(result) < 32768
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=pathlib.Path)
    args = parser.parse_args()
    executable = str(args.executable.resolve())
    with tempfile.TemporaryDirectory(prefix="x1-shared-kanji-") as temp:
        folder = pathlib.Path(temp)
        font = folder / "synthetic-physical.bin"
        font.write_bytes(bytes(pattern(a) for a in range(131072)))
        for loaded in (False, True):
            rom = folder / f"cpu-{loaded}.bin"
            rom.write_bytes(fixture(loaded))
            for warm in (False, True):
                command = [executable, "--rom", str(rom), "--cycles", "6400000"]
                if loaded:
                    command += ["--kanji-physical", str(font)]
                if warm:
                    command += ["--reset-at", "100", "--reset-for-us", "10"]
                result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=180)
                report = json.loads(result.stdout.splitlines()[-1])
                expected = b"WARM" if warm else b"KAN!"
                assert report["turbo_kanji"] and report["halted"] and report["peek"].startswith(expected.hex()), report
                print(json.dumps({"loaded": loaded, "warm": warm, "sys_hz": report["sys_hz"],
                                  "video_hz": report["video_hz"], "peek": report["peek"][:8]}), flush=True)
        bad = folder / "short.bin"
        bad.write_bytes(b"synthetic")
        result = subprocess.run([executable, "--kanji-physical", str(bad)], capture_output=True, text=True)
        assert result.returncode != 0 and "exactly 131072" in result.stderr, result
    print("PASS: shared CPU 1024 INI bytes, all banks/halves, absent/read-only/level2/ANK, cold/warm, loader length")


if __name__ == "__main__":
    main()
