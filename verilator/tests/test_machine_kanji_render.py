"""Original CPU-programmed Kanji raster; compare actual RGB, no native assets."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program


def pattern(address):
    return ((address * 37) ^ (address >> 4) ^ (address >> 12) ^ (address >> 16)) & 255


def fixture(high, columns=80):
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    out(0x1A02, 0x40 if columns == 40 else 0)
    p.emit(0xED, 0x78)
    for port in (0x2000, 0x3000, 0x3800):
        p.word(0x01, port)
        p.word(0x21, 2048)
        label = f"fill{port}"
        p.label(label)
        if port == 0x2000:
            # Reverse independently of the absent-level-2 selection below.
            p.emit(0x79, 0xE6, 0x40, 0x0F, 0x0F, 0x0F, 0xF6, 7)
        elif port == 0x3000:
            p.emit(0x79)
        else:
            # All banks, alternating halves; bit 5 selects absent level 2.
            p.emit(0x79, 0xE6, 0x10, 0x07, 0x07, 0xF6, 0x80, 0x57,
                   0x79, 0xE6, 0x20, 0x0F, 0xB2, 0x57,
                   0x79, 0xE6, 0x0F, 0xB2)
        p.emit(0xED, 0x79, 0x03, 0x2B, 0x7C, 0xB5)
        p.jump(0xC2, label)
    out(0x1FD0, int(high))
    registers = [55 if columns == 40 else 111, columns,
                 46 if columns == 40 else 92, 0x28, 27, 0, 25, 26, 0,
                 15 if high else 7, 0, 0, 0, 0, 0, 0]
    for index, value in enumerate(registers):
        out(0x1800, index)
        out(0x1801, value)
    for index, value in enumerate(b"KPIX"):
        p.store(0xF000 + index, value)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path,
                        help="preserve synthetic ROM/font, actual PPMs and reports in a new directory")
    parser.add_argument("--physical-rom", type=pathlib.Path,
                        help="optional authorized 131072-byte physical candidate, not an emulator export")
    args = parser.parse_args()
    executable = str(args.executable.resolve())
    with tempfile.TemporaryDirectory(prefix="x1-kanji-pixels-") as directory:
        root = args.output if args.output else pathlib.Path(directory)
        if args.output:
            root.mkdir(parents=True, exist_ok=False)
        font = root / "original.physical"
        if args.physical_rom:
            font = args.physical_rom.resolve()
            font_bytes = font.read_bytes()
            assert len(font_bytes) == 131072, "physical first-level ROM must be exactly 131072 bytes"
        else:
            font_bytes = bytes(pattern(address) for address in range(131072))
            font.write_bytes(font_bytes)
        font_hash = hashlib.sha256(font_bytes).hexdigest()
        print(json.dumps({"physical_rom_sha256": font_hash,
                          "private_candidate": bool(args.physical_rom)}), flush=True)
        cases = [(high, columns, loaded, False) for high in (False, True)
                 for columns in (40, 80) for loaded in (False, True)]
        cases += [(high, 80, True, True) for high in (False, True)]
        for high, columns, loaded, warm in cases:
            name = f"{'high' if high else 'standard'}-{columns}-{'loaded' if loaded else 'absent'}-{'warm' if warm else 'cold'}"
            rom, frame = root / f"{name}.rom", root / f"{name}.ppm"
            rom.write_bytes(fixture(high, columns))
            command = [executable, "--rom", str(rom), "--cycles", "9600000", "--frame", str(frame)]
            if loaded:
                command += ["--kanji-physical", str(font)]
            if warm:
                command += ["--reset-at", "120", "--reset-for-us", "10"]
            result = subprocess.run(command,
                                    capture_output=True, text=True, timeout=180)
            (root / f"{name}.stdout.log").write_text(result.stdout)
            (root / f"{name}.stderr.log").write_text(result.stderr)
            assert result.returncode == 0, result.stderr
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["halted"] and report["peek"].startswith(b"KPIX".hex()), report
            assert report["turbo_kanji"] and report["frames"] >= 3, report
            assert (report["sys_hz"], report["video_hz"]) == (32000000, 42954540), report
            expected_hs = 112 * (16 if high else 24) * 1e12 / 42954540
            expected_vs = expected_hs * 28 * (16 if high else 8)
            # Sync edges are observed on the 32 MHz reference scheduler;
            # permit two reference-edge quanta, not percentage-based drift.
            assert abs(report["hs_period_ps"] - expected_hs) <= 62500, report
            assert abs(report["vs_period_ps"] - expected_vs) <= 62500, report
            header, dimensions, maximum, pixels = frame.read_bytes().split(b"\n", 3)
            width, height = map(int, dimensions.split())
            assert (header, maximum, width, height) == (b"P6", b"255", columns * 8, 400 if high else 200), report
            errors = []
            for y in range(height):
                for x in range(width):
                    cell = (y // (16 if high else 8)) * columns + x // 8
                    row = y % 16 if high else (y % 8) * 2
                    address = ((cell // 16) % 2) * 65536 + (cell % 16) * 4096 + (cell % 256) * 16 + row
                    bits = 0 if not loaded or cell & 32 else font_bytes[address]
                    lit = bool(bits & (128 >> (x % 8))) ^ bool(cell & 64)
                    expected = bytes([255 if lit else 0]) * 3
                    offset = (y * width + x) * 3
                    if pixels[offset:offset + 3] != expected and len(errors) < 12:
                        errors.append((x, y, address, expected.hex(), pixels[offset:offset + 3].hex()))
            assert not errors, (high, errors, report)
            print(f"PASS actual CPU Kanji RGB: {name} {width}x{height}, bank/half/glyph/row/reverse/absent-level2", flush=True)


if __name__ == "__main__":
    main()
